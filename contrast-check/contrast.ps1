<#
.SYNOPSIS
    WCAG 2.2 AA colour contrast check for a site's CSS, in its light and dark themes.

.DESCRIPTION
    Reads CSS files (following their local @imports), works out the light theme and
    any dark theme from the CSS custom properties, and reports:
      1. The themes found and what the theme colours resolve to in each.
      2. The contrast of each pair of theme colours, and of the palette colours
         when the theme maps palette variables to theme variables.
      3. The contrast of the colour pairs used in each CSS rule.
      4. Theme problems: undefined variables, dark theme definitions that differ
         (for example a prefers-color-scheme block and a theme switcher selector),
         and fixed colours that don't change with the theme.
    Exits with code 1 when anything fails, 0 otherwise.

    Works with plain CSS that themes with custom properties. It doesn't read Sass,
    Tailwind classes or CSS-in-JS: check single pairs with -Fg and -Bg for those.
    Needs Windows PowerShell 5.1 or PowerShell 7 (pwsh on macOS and Linux).

.PARAMETER Css
    CSS files or folders, comma separated, relative to the current folder. Files are
    followed through their local @imports. Folders are searched for .css files,
    skipping minified files, node_modules and vendor. Pass the entry stylesheet
    when there is one, so the cascade order is right.

.PARAMETER LightSelectors
    Selectors that define the default (light) theme variables. Default: :root, html

.PARAMETER DarkSelectors
    Selectors that define the dark theme, for example ':root[data-theme="dark"]' or
    '.dark'. Default: rules inside @media (prefers-color-scheme: dark) and selectors
    with "dark" as a word in them.

.PARAMETER PageBg
    The page background, as a colour or a variable name. Default: the background of
    the html or body rule, or white.

.PARAMETER TokensOnly
    The project only allows theme variables in components: report palette variables
    and hardcoded colours as failures instead of warnings.

.PARAMETER Fg
    Check a single pair instead: a colour (9C0D38, '#9C0D38', 'rgb(0 0 0)', white)
    or a variable name (accent-color). Variables need -Css and are resolved in each theme.

.PARAMETER Bg
    The background for -Fg, in the same formats.

.PARAMETER All
    Also list the CSS rule pairs that pass.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File contrast.ps1 -Css assets/css/style.css

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File contrast.ps1 -Css assets/css/style.css -DarkSelectors ':root[data-theme="dark"]' -TokensOnly

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File contrast.ps1 -Css assets/css/style.css -Fg accent-color -Bg bg-color

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File contrast.ps1 -Fg 9C0D38 -Bg FBFBFB
#>
[CmdletBinding()]
param(
    [string[]]$Css,
    [string[]]$LightSelectors = @(':root', 'html'),
    [string[]]$DarkSelectors,
    [string]$PageBg,
    [switch]$TokensOnly,
    [string]$Fg,
    [string]$Bg,
    [switch]$All
)

$ErrorActionPreference = 'Stop'
$Inv = [Globalization.CultureInfo]::InvariantCulture
$BaseDir = (Get-Location).Path

$TextMin = 4.5   # 1.4.3 normal text
$UiMin = 3.0     # 1.4.3 large text, 1.4.11 non-text contrast

$NamedColors = @{
    'black' = '#000000'; 'white' = '#FFFFFF'; 'red' = '#FF0000'; 'green' = '#008000'
    'blue' = '#0000FF'; 'yellow' = '#FFFF00'; 'orange' = '#FFA500'; 'purple' = '#800080'
    'pink' = '#FFC0CB'; 'gray' = '#808080'; 'grey' = '#808080'; 'silver' = '#C0C0C0'
    'navy' = '#000080'; 'maroon' = '#800000'; 'teal' = '#008080'; 'olive' = '#808000'
    'lime' = '#00FF00'; 'aqua' = '#00FFFF'; 'fuchsia' = '#FF00FF'; 'cyan' = '#00FFFF'
    'magenta' = '#FF00FF'; 'gold' = '#FFD700'; 'crimson' = '#DC143C'; 'whitesmoke' = '#F5F5F5'
    'darkgray' = '#A9A9A9'; 'darkgrey' = '#A9A9A9'; 'lightgray' = '#D3D3D3'; 'lightgrey' = '#D3D3D3'
    'dimgray' = '#696969'; 'dimgrey' = '#696969'
}
$NamedPattern = '(?<![\w-])(' + (($NamedColors.Keys | Sort-Object Length -Descending) -join '|') + ')(?![\w-])'
$ColorPattern = '(?i)var\(\s*--[\w-]+[^)]*\)|#[0-9a-f]{3,8}\b|\b(?:rgba?|hsla?)\([^)]*\)|' + $NamedPattern


# Colour maths (WCAG 2.2 relative luminance and contrast ratio)
# ==========================================================================

function ConvertTo-Hex([string]$value) {
    if (-not $value) { return $null }
    $v = $value.Trim()

    if ($v -match '^#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$') {
        $h = $Matches[1]
        if ($h.Length -le 4) { $h = -join ($h.ToCharArray() | ForEach-Object { "$_$_" }) }
        if ($h.Length -eq 8) {
            if ($h.Substring(6).ToUpper() -ne 'FF') { return $null }   # translucent
            $h = $h.Substring(0, 6)
        }
        return '#' + $h.ToUpper()
    }

    if ($NamedColors.ContainsKey($v.ToLower())) { return $NamedColors[$v.ToLower()] }

    if ($v -match '^(?i)(rgba?|hsla?)\(\s*([^)]*)\)$') {
        $fn = $Matches[1].ToLower()
        $parts = @($Matches[2] -split '[\s,/]+' | Where-Object { $_ })
        if ($parts.Count -lt 3) { return $null }
        try {
            if ($parts.Count -ge 4) {
                $alpha = $parts[3]
                if ($alpha.EndsWith('%')) { $a = [double]::Parse($alpha.TrimEnd('%'), $Inv) / 100 }
                else { $a = [double]::Parse($alpha, $Inv) }
                if ($a -lt 1) { return $null }   # translucent
            }
            if ($fn.StartsWith('rgb')) {
                $rgb = foreach ($p in $parts[0..2]) {
                    if ($p.EndsWith('%')) { [double]::Parse($p.TrimEnd('%'), $Inv) * 2.55 }
                    else { [double]::Parse($p, $Inv) }
                }
            }
            else {
                $hue = [double]::Parse(($parts[0] -replace '(?i)deg$', ''), $Inv)
                $hue = (($hue % 360) + 360) % 360
                $s = [double]::Parse($parts[1].TrimEnd('%'), $Inv) / 100
                $l = [double]::Parse($parts[2].TrimEnd('%'), $Inv) / 100
                $c = (1 - [math]::Abs(2 * $l - 1)) * $s
                $x = $c * (1 - [math]::Abs((($hue / 60) % 2) - 1))
                $m = $l - $c / 2
                $sector = [math]::Floor($hue / 60)
                $rgb1 = switch ($sector) {
                    0 { @($c, $x, 0) }
                    1 { @($x, $c, 0) }
                    2 { @(0, $c, $x) }
                    3 { @(0, $x, $c) }
                    4 { @($x, 0, $c) }
                    default { @($c, 0, $x) }
                }
                $rgb = $rgb1 | ForEach-Object { ($_ + $m) * 255 }
            }
        }
        catch { return $null }
        return '#' + (($rgb | ForEach-Object { '{0:X2}' -f [int][math]::Round([math]::Max(0, [math]::Min(255, $_))) }) -join '')
    }

    return $null
}

function Get-Luminance([string]$hex) {
    $h = $hex.TrimStart('#')
    $c = foreach ($i in 0, 2, 4) {
        $s = [Convert]::ToInt32($h.Substring($i, 2), 16) / 255
        if ($s -le 0.04045) { $s / 12.92 } else { [math]::Pow(($s + 0.055) / 1.055, 2.4) }
    }
    return 0.2126 * $c[0] + 0.7152 * $c[1] + 0.0722 * $c[2]
}

function Get-Contrast([string]$a, [string]$b) {
    $la = Get-Luminance $a
    $lb = Get-Luminance $b
    return ([math]::Max($la, $lb) + 0.05) / ([math]::Min($la, $lb) + 0.05)
}

# Truncate rather than round, so 4.499 never shows as 4.50
function Format-Ratio([double]$ratio) {
    return ([math]::Floor($ratio * 100) / 100).ToString('0.00', $Inv) + ':1'
}

function Get-Verdict([double]$ratio) {
    if ($ratio -ge $TextMin) { return 'AA' }
    if ($ratio -ge $UiMin) { return 'large text/UI only' }
    return 'FAIL'
}


# Helpers
# ==========================================================================

# Split "a, b" lists on commas outside brackets. powershell -File passes "a,b" as
# one string, so array parameters are split here.
function Split-List([string[]]$values) {
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($v in $values) {
        if (-not $v) { continue }
        $depth = 0
        $start = 0
        for ($k = 0; $k -lt $v.Length; $k++) {
            $ch = $v[$k]
            if ($ch -eq '(' -or $ch -eq '[') { $depth++ }
            elseif ($ch -eq ')' -or $ch -eq ']') { $depth-- }
            elseif ($ch -eq ',' -and $depth -eq 0) {
                $out.Add($v.Substring($start, $k - $start).Trim())
                $start = $k + 1
            }
        }
        $out.Add($v.Substring($start).Trim())
    }
    return @($out | Where-Object { $_ })
}

# Compare selectors without quotes, spaces or case (quotes are also lost when
# arguments pass through powershell -File)
function ConvertTo-SelectorKey([string]$selector) {
    return ($selector -replace '["'']', '' -replace '\s+', '').ToLower()
}

function Get-DisplayPath([string]$path) {
    if ($path.StartsWith($BaseDir, [StringComparison]::OrdinalIgnoreCase)) {
        $path = $path.Substring($BaseDir.Length).TrimStart('\', '/')
    }
    return $path -replace '\\', '/'
}

# First colour in a value: a variable, hex, rgb()/hsl() or a named colour
function Get-ColorToken([string]$value) {
    $m = [regex]::Match(($value -replace '(?i)url\([^)]*\)', ''), $ColorPattern)
    if ($m.Success) { return $m.Value }
    return $null
}

# Resolve a colour token to #RRGGBB in a theme, or $null (translucent, unknown...)
function Resolve-Color([string]$value, [hashtable]$vars, [int]$depth = 0) {
    if (-not $value -or $depth -gt 10) { return $null }
    $v = $value.Trim()
    if ($v -match '^var\(\s*(--[\w-]+)\s*(?:,\s*(.+))?\)$') {
        $name = $Matches[1]
        $fallback = $Matches[2]
        if ($vars.ContainsKey($name)) { return Resolve-Color $vars[$name] $vars ($depth + 1) }
        return Resolve-Color $fallback $vars ($depth + 1)
    }
    return ConvertTo-Hex $v
}

# A colour or variable name given on the command line, as a colour token
function ConvertTo-Token([string]$value) {
    $v = $value.Trim()
    if ($v -match '^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$') { return '#' + $Matches[1] }
    if ($NamedColors.ContainsKey($v.ToLower()) -or $v -match '^(?i)(var|rgba?|hsla?)\(') { return $v }
    return 'var(--' + $v.TrimStart('-') + ')'
}

# What a colour property paints, and so the contrast it needs
function Get-PropKind([string]$prop) {
    if ($prop -eq 'color') { return 'text' }
    if ($prop -match '^(fill|stroke)$') { return 'graphic' }
    if ($prop -match '^outline(-color)?$') { return 'outline' }
    if ($prop -match '^border(-(top|right|bottom|left|block|inline)(-(start|end))?)?(-color)?$') { return 'border' }
    return $null
}


# CSS parsing
# ==========================================================================

# Blank out a match but keep its line breaks, so line numbers stay right
$KeepLines = [Text.RegularExpressions.MatchEvaluator] { param($m) $m.Value -replace '[^\n]', ' ' }

function Get-LineStarts([string]$text) {
    $starts = New-Object System.Collections.Generic.List[int]
    $starts.Add(0)
    $k = $text.IndexOf("`n")
    while ($k -ge 0) {
        $starts.Add($k + 1)
        $k = $text.IndexOf("`n", $k + 1)
    }
    return , $starts.ToArray()
}

function Get-LineNumber([int[]]$starts, [int]$index) {
    $r = [Array]::BinarySearch($starts, $index)
    if ($r -lt 0) { $r = (-bnot $r) - 1 }
    return $r + 1
}

function Read-CssFile([string]$path) {
    $raw = [IO.File]::ReadAllText($path) -replace "`r`n", "`n"
    $text = [regex]::Replace($raw, '/\*[\s\S]*?\*/', $KeepLines)
    $starts = Get-LineStarts $text
    $rules = New-Object System.Collections.Generic.List[object]
    $imports = New-Object System.Collections.Generic.List[string]
    $groups = New-Object System.Collections.Generic.List[string]   # open @media/@supports...
    $segStart = 0
    $i = 0

    while ($true) {
        $i = $text.IndexOfAny([char[]]'{};', $i)
        if ($i -lt 0) { break }
        $ch = $text[$i]

        if ($ch -eq ';') {
            $statement = $text.Substring($segStart, $i - $segStart).Trim()
            if ($statement -match '^@import\s+(?:url\(\s*)?["'']?([^"'')\s;]+)') { $imports.Add($Matches[1]) }
            $segStart = $i + 1
            $i++
            continue
        }

        if ($ch -eq '}') {
            if ($groups.Count) { $groups.RemoveAt($groups.Count - 1) }
            $segStart = $i + 1
            $i++
            continue
        }

        # An opening brace: a group at-rule, or a block that runs to its matching brace
        $prelude = $text.Substring($segStart, $i - $segStart)
        $preludeText = $prelude.Trim() -replace '\s+', ' '
        if ($preludeText -match '^@(media|supports|layer|container|scope|document)\b') {
            $groups.Add($preludeText)
            $segStart = $i + 1
            $i++
            continue
        }

        $depth = 1
        $j = $i + 1
        while ($depth -gt 0) {
            $j = $text.IndexOfAny([char[]]'{}', $j)
            if ($j -lt 0) { $j = $text.Length + 1; break }
            if ($text[$j] -eq '{') { $depth++ } else { $depth-- }
            $j++
        }
        $bodyStart = $i + 1
        $bodyEnd = [math]::Min($j - 1, $text.Length)

        # @font-face, @keyframes, @page... hold no colour pairs we can check
        if (-not $preludeText.StartsWith('@')) {
            # Ignore nested rules (CSS nesting) inside the body
            $body = $text.Substring($bodyStart, $bodyEnd - $bodyStart)
            while ($body.Contains('{')) {
                $flat = [regex]::Replace($body, '[^;{}]*\{[^{}]*\}', $KeepLines)
                if ($flat -eq $body) { break }
                $body = $flat
            }

            $decls = New-Object System.Collections.Generic.List[object]
            foreach ($d in [regex]::Matches($body, '(?<prop>--[\w-]+|[a-zA-Z-]+)\s*:\s*(?<val>[^;]+)')) {
                $prop = $d.Groups['prop'].Value
                if (-not $prop.StartsWith('--')) { $prop = $prop.ToLower() }
                $decls.Add([pscustomobject]@{
                    Prop  = $prop
                    Value = ($d.Groups['val'].Value.Trim() -replace '\s+', ' ' -replace '\s*!important$', '')
                    Line  = Get-LineNumber $starts ($bodyStart + $d.Index)
                })
            }

            $selStart = $segStart + ($prelude.Length - $prelude.TrimStart().Length)
            $rules.Add([pscustomobject]@{
                File     = $path
                Selector = $preludeText
                Parts    = @(Split-List @($preludeText) | ForEach-Object { ConvertTo-SelectorKey $_ })
                Media    = ($groups -join ' ')
                Line     = Get-LineNumber $starts $selStart
                Decls    = $decls
            })
        }

        $segStart = [math]::Min($j, $text.Length)
        $i = $segStart
    }

    return [pscustomobject]@{ Path = $path; Rules = $rules; Imports = $imports }
}

$CssFiles = New-Object System.Collections.Generic.List[object]
$SeenFiles = @{}

# Imports go before the file that imports them, as in the cascade
function Add-CssFile([string]$path) {
    $full = (Resolve-Path -LiteralPath $path).Path
    if ($SeenFiles.ContainsKey($full)) { return }
    $SeenFiles[$full] = $true
    $parsed = Read-CssFile $full
    foreach ($import in $parsed.Imports) {
        if ($import -match '^([a-z]+:)?//') { continue }
        $p = Join-Path (Split-Path $full) ($import -split '[?#]')[0]
        if (Test-Path -LiteralPath $p -PathType Leaf) { Add-CssFile $p }
    }
    $CssFiles.Add($parsed)
}

foreach ($item in (Split-List $Css)) {
    if (-not (Test-Path -LiteralPath $item)) { throw "CSS path not found: $item" }
    if (Test-Path -LiteralPath $item -PathType Container) {
        Get-ChildItem -LiteralPath $item -Filter *.css -Recurse |
            Where-Object { $_.Name -notmatch '[.-]min\.css$' -and $_.FullName -notmatch '[\\/](node_modules|vendor)[\\/]' } |
            Sort-Object FullName |
            ForEach-Object { Add-CssFile $_.FullName }
    }
    else { Add-CssFile $item }
}


# Work out the themes
# ==========================================================================

$LightKeys = @(Split-List $LightSelectors | ForEach-Object { ConvertTo-SelectorKey $_ } | Where-Object { $_ })
$DarkKeys = @(Split-List $DarkSelectors | ForEach-Object { ConvertTo-SelectorKey $_ } | Where-Object { $_ })
$RootKeys = @($LightKeys + @(':root', 'html', 'body') | Select-Object -Unique)

# A selector part is "on the root" when it is :root/html/body, maybe with a
# class, attribute or pseudo-class: :root[data-theme=dark], html.dark...
function Test-OnRoot([string]$part, [string[]]$roots) {
    foreach ($r in $roots) {
        if ($part -eq $r) { return $true }
        if ($part.StartsWith($r) -and $part.Length -gt $r.Length -and '[.:#'.Contains($part[$r.Length])) { return $true }
    }
    return $false
}

# Which theme a selector part belongs to: Dark, Light or Both
function Get-PartTheme([string]$part) {
    if ($DarkKeys.Count) {
        foreach ($d in $DarkKeys) { if ($part.StartsWith($d)) { return 'Dark' } }
    }
    elseif ($part -match '(^|[^a-z])dark([^a-z]|$)') { return 'Dark' }
    if ($part -match '(^|[^a-z])light([^a-z]|$)' -and $part -notmatch ':not\([^)]*light') { return 'Light' }
    return 'Both'
}

# Which theme a rule applies to: Dark, Light or Both
function Get-RuleTheme($rule) {
    if ($rule.Media -match '(?i)prefers-color-scheme\s*:\s*dark') { return 'Dark' }
    if ($rule.Media -match '(?i)prefers-color-scheme\s*:\s*light') { return 'Light' }
    $themes = @($rule.Parts | ForEach-Object { Get-PartTheme $_ } | Select-Object -Unique)
    if ($themes.Count -eq 1) { return $themes[0] }
    return 'Both'
}

$light = @{}
$lightOrder = New-Object System.Collections.Generic.List[string]
$darkVariants = [ordered]@{}
$darkOrder = New-Object System.Collections.Generic.List[string]
$hasDark = $false

foreach ($file in $CssFiles) {
    foreach ($rule in $file.Rules) {
        $theme = Get-RuleTheme $rule
        $rule | Add-Member -NotePropertyName Theme -NotePropertyValue $theme
        if ($theme -eq 'Dark') { $hasDark = $true }

        $custom = @($rule.Decls | Where-Object { $_.Prop.StartsWith('--') })
        if ($custom.Count -eq 0) { continue }

        if ($theme -eq 'Dark') {
            $key = ($rule.Media + ' ' + $rule.Selector).Trim()
            if (-not $darkVariants.Contains($key)) { $darkVariants[$key] = @{} }
            foreach ($d in $custom) {
                $darkVariants[$key][$d.Prop] = $d.Value
                if (-not $darkOrder.Contains($d.Prop)) { $darkOrder.Add($d.Prop) }
            }
        }
        elseif ($theme -ne 'Dark' -and @($rule.Parts | Where-Object { -not (Test-OnRoot $_ $LightKeys) }).Count -eq 0) {
            foreach ($d in $custom) {
                $light[$d.Prop] = $d.Value
                if (-not $lightOrder.Contains($d.Prop)) { $lightOrder.Add($d.Prop) }
            }
        }
    }
}

$dark = $light.Clone()
foreach ($variant in $darkVariants.Values) {
    foreach ($k in $variant.Keys) { $dark[$k] = $variant[$k] }
}
$Themes = [ordered]@{ 'Light' = $light }
if ($hasDark) { $Themes['Dark'] = $dark }

# Palette: literal colours that other variables point to (--accent: var(--red))
$referenced = @{}
$allDefs = @($light.Values) + @($darkVariants.Values | ForEach-Object { $_.Values })
foreach ($value in $allDefs) {
    foreach ($m in [regex]::Matches([string]$value, 'var\(\s*(--[\w-]+)')) { $referenced[$m.Groups[1].Value] = $true }
}
$paletteNames = @($lightOrder | Where-Object { $referenced.ContainsKey($_) -and (ConvertTo-Hex $light[$_]) })

# Theme colours: the colour variables the dark theme changes, or all of them
if ($hasDark -and $darkOrder.Count) { $candidates = $darkOrder } else { $candidates = $lightOrder }
$themeNames = @($candidates | Where-Object {
    $name = $_
    $paletteNames -notcontains $name -and @($Themes.Keys | Where-Object { Resolve-Color "var($name)" $Themes[$_] }).Count -eq $Themes.Count
})

# Page background in each theme
$pageBgToken = @{}
if ($PageBg) {
    foreach ($t in $Themes.Keys) { $pageBgToken[$t] = ConvertTo-Token $PageBg }
}
else {
    foreach ($file in $CssFiles) {
        foreach ($rule in $file.Rules) {
            if (@($rule.Parts | Where-Object { -not (Test-OnRoot $_ $RootKeys) }).Count) { continue }
            foreach ($d in $rule.Decls) {
                if ($d.Prop -notmatch '^background(-color)?$') { continue }
                $token = Get-ColorToken $d.Value
                if (-not $token) { continue }
                foreach ($t in $Themes.Keys) {
                    if ($rule.Theme -eq 'Both' -or $rule.Theme -eq $t) { $pageBgToken[$t] = $token }
                }
            }
        }
    }
    if (-not $pageBgToken['Light']) { $pageBgToken['Light'] = '#FFFFFF' }
}


# Single pair mode
# ==========================================================================

if ($Fg -or $Bg) {
    if (-not ($Fg -and $Bg)) { throw 'Use -Fg and -Bg together.' }
    $fgToken = ConvertTo-Token $Fg
    $bgToken = ConvertTo-Token $Bg
    $usesVars = ($fgToken + $bgToken).Contains('var(')
    if ($usesVars -and $CssFiles.Count -eq 0) { throw 'Pass -Css so the variables can be resolved.' }

    Write-Output "$fgToken on $bgToken"
    $pairThemes = @($Themes.Keys)
    if (-not $usesVars) { $pairThemes = @('Light') }   # the same in every theme
    $exit = 0
    foreach ($theme in $pairThemes) {
        $label = $theme
        if (-not $usesVars) { $label = 'Any' }
        $fgHex = Resolve-Color $fgToken $Themes[$theme]
        $bgHex = Resolve-Color $bgToken $Themes[$theme]
        if (-not $fgHex -or -not $bgHex) {
            Write-Output ('  {0,-6} cannot resolve (unknown variable or translucent colour)' -f $label)
            $exit = 1
            continue
        }
        $ratio = Get-Contrast $fgHex $bgHex
        Write-Output ('  {0,-6} {1} on {2}  {3,-9} {4}' -f $label, $fgHex, $bgHex, (Format-Ratio $ratio), (Get-Verdict $ratio))
    }
    Write-Output ''
    Write-Output 'AA needs 4.5:1 for text, 3:1 for large text (24px, or 18.66px bold) and for UI/graphics.'
    exit $exit
}

if ($CssFiles.Count -eq 0) { throw 'Pass -Css with the stylesheet(s) to check, or -Fg and -Bg for a single pair.' }


# Report
# ==========================================================================

$failures = 0
$checks = 0
$warnings = 0

Write-Output 'Contrast check (WCAG 2.2 AA)'
Write-Output 'AA needs 4.5:1 for text, 3:1 for large text (24px, or 18.66px bold) and for UI/graphics.'
Write-Output ''

$shown = @($CssFiles | Select-Object -First 8 | ForEach-Object { Get-DisplayPath $_.Path })
$more = ''
if ($CssFiles.Count -gt 8) { $more = " and $($CssFiles.Count - 8) more" }
Write-Output ('CSS: {0} files: {1}{2}' -f $CssFiles.Count, ($shown -join ', '), $more)
Write-Output ('Light theme: {0} variables from {1}' -f $light.Count, ($LightSelectors -join ', '))
if ($hasDark) {
    if ($darkVariants.Count) {
        Write-Output 'Dark theme:'
        foreach ($key in $darkVariants.Keys) { Write-Output "   $key" }
    }
    else { Write-Output 'Dark theme: rules only, no variables' }
}
else { Write-Output 'Dark theme: none found (pass -DarkSelectors if there is one)' }
$bgText = foreach ($t in $Themes.Keys) {
    $tok = $pageBgToken[$t]
    if ($tok) { '{0} {1} ({2})' -f $t, $tok, (Resolve-Color $tok $Themes[$t]) } else { "$t unknown" }
}
Write-Output ('Page background: {0}' -f ($bgText -join ', '))
Write-Output ''

# 1. Theme colours
Write-Output '1. Theme colours'
if ($themeNames.Count -eq 0) {
    Write-Output '   No colour variables found.'
}
else {
    $header = '   {0,-24}' -f ''
    foreach ($t in $Themes.Keys) { $header += '{0,-10}' -f $t }
    Write-Output $header
    foreach ($name in $themeNames) {
        $line = '   {0,-24}' -f $name
        foreach ($t in $Themes.Keys) { $line += '{0,-10}' -f (Resolve-Color "var($name)" $Themes[$t]) }
        Write-Output $line
    }
}
Write-Output ''

# 2. Theme colour pairs
function Write-PairTable([string[]]$names, $themes) {
    $header = '   {0,-40}' -f ''
    foreach ($t in $themes.Keys) { $header += '{0,-30}' -f $t }
    Write-Output $header
    for ($i = 0; $i -lt $names.Count; $i++) {
        for ($j = $i + 1; $j -lt $names.Count; $j++) {
            $line = '   {0,-40}' -f "$($names[$i]) / $($names[$j])"
            foreach ($t in $themes.Keys) {
                $ratio = Get-Contrast (Resolve-Color "var($($names[$i]))" $themes[$t]) (Resolve-Color "var($($names[$j]))" $themes[$t])
                $line += '{0,-30}' -f ('{0,-9} {1}' -f (Format-Ratio $ratio), (Get-Verdict $ratio))
            }
            Write-Output $line
        }
    }
}

Write-Output '2. Theme colour pairs'
if ($themeNames.Count -lt 2) {
    Write-Output '   Fewer than two colour variables: nothing to pair.'
}
elseif ($themeNames.Count -gt 12) {
    Write-Output "   $($themeNames.Count) colour variables: too many pairs to list. Check pairs with -Fg and -Bg."
}
else { Write-PairTable $themeNames $Themes }
if ($paletteNames.Count -ge 2 -and $paletteNames.Count -le 12) {
    Write-Output ''
    Write-Output '   Palette pairs (raw colours behind the theme variables)'
    Write-PairTable $paletteNames ([ordered]@{ 'Any theme' = $light })
}
Write-Output ''

# 3. Colour pairs in CSS rules
$results = New-Object System.Collections.Generic.List[object]
foreach ($file in $CssFiles) {
    foreach ($rule in $file.Rules) {
        $bgToken = $null
        $bgUnknown = $false
        $colorToken = $null
        foreach ($d in $rule.Decls) {
            if ($d.Prop -match '^background(-color)?$') {
                $bgToken = Get-ColorToken $d.Value
                $bgUnknown = (-not $bgToken -and $d.Value -match '(?i)url\(|gradient')
            }
            if ($d.Prop -eq 'color') { $colorToken = Get-ColorToken $d.Value }
        }
        if ($bgUnknown) { continue }

        $ruleThemes = @($Themes.Keys | Where-Object { $rule.Theme -eq 'Both' -or $rule.Theme -eq $_ })

        foreach ($d in $rule.Decls) {
            $kind = Get-PropKind $d.Prop
            if (-not $kind) { continue }
            $fgToken = Get-ColorToken $d.Value
            if (-not $fgToken -and $d.Value -match '(?i)currentColor') { $fgToken = $colorToken }
            if (-not $fgToken) { continue }

            # Text and icons sit on the rule's own background, or the page if it sets
            # none. Borders and outlines sit against what is around the element.
            $sameRule = ($kind -eq 'text' -or $kind -eq 'graphic') -and $bgToken
            if ($kind -eq 'text') { $need = $TextMin } else { $need = $UiMin }

            $ratios = [ordered]@{}
            $againstShown = $null
            foreach ($t in $ruleThemes) {
                if ($sameRule) { $against = $bgToken } else { $against = $pageBgToken[$t] }
                if (-not $againstShown) { $againstShown = $against }
                $fgHex = Resolve-Color $fgToken $Themes[$t]
                $bgHex = Resolve-Color $against $Themes[$t]
                if ($fgHex -and $bgHex) { $ratios[$t] = Get-Contrast $fgHex $bgHex }
            }
            if ($ratios.Count -eq 0) { continue }

            $worst = ($ratios.Values | Measure-Object -Minimum).Minimum
            $note = ''
            if ($worst -ge $need) {
                $status = 'PASS'
            }
            elseif ($sameRule -or ($kind -eq 'outline' -and $rule.Selector -match 'focus')) {
                $status = 'FAIL'
                if ($kind -eq 'text' -and $worst -ge $UiMin) { $note = 'OK only if this is large text (24px, or 18.66px bold)' }
                elseif ($kind -eq 'outline') { $note = 'focus indicator' }
            }
            else {
                $status = 'CHECK'
                if ($kind -eq 'text' -or $kind -eq 'graphic') {
                    $note = 'rule sets no background: compared with the page background; check the real one (parent element, other rule?)'
                }
                else {
                    $note = 'needs 3:1 only if it is the only visual cue for a control, its state or focus'
                }
            }

            $ratioText = ($ratios.Keys | ForEach-Object { '{0} {1}' -f $_, (Format-Ratio $ratios[$_]) }) -join '  '
            $results.Add([pscustomobject]@{
                Status   = $status
                Location = ('{0}:{1}' -f (Get-DisplayPath $file.Path), $d.Line)
                Selector = ($rule.Media + ' ' + $rule.Selector).Trim()
                Pair     = ('{0}: {1} on {2}' -f $d.Prop, $fgToken, $againstShown)
                Ratios   = ('{0}  (needs {1}:1)' -f $ratioText, $need.ToString($Inv))
                Note     = $note
            })
        }
    }
}

$failed = @($results | Where-Object { $_.Status -eq 'FAIL' })
$toCheck = @($results | Where-Object { $_.Status -eq 'CHECK' })
$passed = @($results | Where-Object { $_.Status -eq 'PASS' })
$failures += $failed.Count
$checks += $toCheck.Count

Write-Output '3. Colour pairs in CSS rules'
$listed = $failed + $toCheck
if ($All) { $listed += $passed }
foreach ($r in $listed) {
    Write-Output ('   {0,-5} {1}  {2}' -f $r.Status, $r.Location, $r.Selector)
    Write-Output ('         {0}' -f $r.Pair)
    Write-Output ('         {0}' -f $r.Ratios)
    if ($r.Note) { Write-Output ('         {0}' -f $r.Note) }
}
Write-Output ('   {0} pairs checked: {1} pass, {2} fail, {3} to check by hand.' -f $results.Count, $passed.Count, $failed.Count, $toCheck.Count)
if (-not $All -and $passed.Count) { Write-Output '   Run with -All to list the passes too.' }
Write-Output ''

# 4. Theme problems
$defined = @{}
foreach ($file in $CssFiles) {
    foreach ($rule in $file.Rules) {
        foreach ($d in $rule.Decls) { if ($d.Prop.StartsWith('--')) { $defined[$d.Prop] = $true } }
    }
}

$errors = New-Object System.Collections.Generic.List[string]
$warns = New-Object System.Collections.Generic.List[string]
$colorProps = 'color|background|border|outline|fill|stroke|shadow|decoration|caret|column-rule'

foreach ($file in $CssFiles) {
    foreach ($rule in $file.Rules) {
        $isTokenRule = @($rule.Parts | Where-Object { -not (Test-OnRoot $_ $RootKeys) }).Count -eq 0 -or
            ($rule.Theme -eq 'Dark' -and @($rule.Decls | Where-Object { -not $_.Prop.StartsWith('--') }).Count -eq 0)

        foreach ($d in $rule.Decls) {
            $where = '{0}:{1}  {2}  {3}: {4}' -f (Get-DisplayPath $file.Path), $d.Line, $rule.Selector, $d.Prop, $d.Value

            foreach ($m in [regex]::Matches($d.Value, 'var\(\s*(--[\w-]+)\s*(,)?')) {
                if (-not $defined.ContainsKey($m.Groups[1].Value) -and -not $m.Groups[2].Success) {
                    $errors.Add("Undefined variable, so the browser ignores the declaration: $where")
                }
            }

            # Theme variables are defined from palette and literal colours: that's fine
            if ($isTokenRule) { continue }
            $isCustom = $d.Prop.StartsWith('--')
            if (-not $isCustom -and $d.Prop -notmatch $colorProps) { continue }
            if ($isCustom -and -not $TokensOnly) { continue }

            $plain = $d.Value -replace '(?i)url\([^)]*\)', '' -replace '"[^"]*"|''[^'']*''', ''
            $palette = @([regex]::Matches($plain, 'var\(\s*(--[\w-]+)') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $paletteNames -contains $_ })
            $hardcoded = $plain -match '(?i)#[0-9a-f]{3,8}\b|\b(rgba?|hsla?|hwb|lab|lch|oklab|oklch)\(' -or $plain -match "(?i)$NamedPattern"

            if ($TokensOnly) {
                if ($palette.Count) { $errors.Add("Palette variable instead of a theme variable: $where") }
                if ($hardcoded) { $errors.Add("Hardcoded colour instead of a theme variable: $where") }
            }
            elseif ($hasDark -and $rule.Theme -eq 'Both' -and ($palette.Count -or $hardcoded)) {
                $warns.Add("Same colour in both themes, check it works in each: $where")
            }
        }
    }
}

# Dark theme definitions that set the same variables (say, a prefers-color-scheme
# block and a theme switcher selector) must set them to the same values
$variantKeys = @($darkVariants.Keys)
for ($i = 0; $i -lt $variantKeys.Count; $i++) {
    for ($j = $i + 1; $j -lt $variantKeys.Count; $j++) {
        $a = $darkVariants[$variantKeys[$i]]
        $b = $darkVariants[$variantKeys[$j]]
        if (@($a.Keys | Where-Object { $b.ContainsKey($_) }).Count -eq 0) { continue }
        foreach ($k in (@($a.Keys) + @($b.Keys) | Sort-Object -Unique)) {
            if ($a[$k] -ne $b[$k]) {
                $errors.Add(('Dark theme definitions differ for {0}: "{1}" in {2}, "{3}" in {4}' -f $k, $a[$k], $variantKeys[$i], $b[$k], $variantKeys[$j]))
            }
        }
    }
}

$failures += $errors.Count
$warnings += $warns.Count

Write-Output '4. Theme problems'
if ($errors.Count -eq 0 -and $warns.Count -eq 0) { Write-Output '   None found.' }
foreach ($e in $errors) { Write-Output "   FAIL  $e" }
foreach ($w in $warns) { Write-Output "   WARN  $w" }
Write-Output ''

Write-Output ('Summary: {0} failures, {1} to check by hand, {2} warnings.' -f $failures, $checks, $warnings)
if ($failures -gt 0) { exit 1 }
exit 0
