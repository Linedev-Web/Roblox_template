# Cree un nouveau jeu a partir du template.
# Usage : .\nouveau-jeu.ps1 -Nom "MonJeu" -Titre "Mon Super Jeu"
#   -Nom    : nom technique (dossier, projet Rojo, DataStore), lettres et chiffres
#   -Titre  : nom affiche dans le jeu (facultatif, -Nom par defaut)
#   -Dossier : dossier parent (facultatif, celui du template par defaut)
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^[A-Za-z][A-Za-z0-9]*$')][string]$Nom,
    [string]$Titre = $Nom,
    [string]$Dossier = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$source = $PSScriptRoot
$cible = Join-Path $Dossier $Nom

if (Test-Path $cible) {
    throw "Le dossier $cible existe deja."
}

# Copie sans l'historique Git du template ni les places de test
New-Item -ItemType Directory -Path $cible | Out-Null
Get-ChildItem -Path $source -Force | Where-Object { $_.Name -notin @('.git', 'nouveau-jeu.ps1') -and $_.Extension -ne '.rbxl' } | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $cible -Recurse -Force
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
function Remplacer([string]$fichier, [string]$ancien, [string]$nouveau) {
    $texte = [System.IO.File]::ReadAllText($fichier, $utf8)
    [System.IO.File]::WriteAllText($fichier, $texte.Replace($ancien, $nouveau), $utf8)
}

# Projet Rojo, nom affiche et DataStore
foreach ($projet in @('default.project.json', 'place.project.json')) {
    Remplacer (Join-Path $cible $projet) '"name": "Template"' ('"name": "' + $Nom + '"')
}
$config = Join-Path $cible 'src\shared\Config.luau'
Remplacer $config 'Config.GameName = "Mon Jeu"' ('Config.GameName = "' + $Titre.Replace('"', '\"') + '"')
Remplacer $config 'Config.DataStoreName = "MonJeu_Profils_v1"' ('Config.DataStoreName = "' + $Nom + '_Profils_v1"')

# Le CLAUDE.md du jeu commence par sa propre fiche, le socle suit
$claude = Join-Path $cible 'CLAUDE.md'
$socle = [System.IO.File]::ReadAllText($claude, $utf8)
$entete = @"
# $Titre ($Nom)

Jeu incrémental Roblox de Yoan (Linedev), créé le $(Get-Date -Format 'yyyy-MM-dd') à partir du
template ``C:\workspace\Roblox\Template``.

## Concept du jeu

À compléter : thème, monnaies, améliorations, ce qui rend ce jeu différent.

## Place Roblox

- Place de départ : ``$Nom.rbxl`` (à ouvrir dans Studio puis « Sauvegarder sur Roblox »).
- Identifiant de la place : à compléter.

---

"@
[System.IO.File]::WriteAllText($claude, $entete + $socle, $utf8)
Remplacer (Join-Path $cible 'README.md') '# Template de jeu incrémental Roblox' ('# ' + $Titre)

# Place de depart : sol, point d'apparition et scripts
$rojo = Join-Path $env:USERPROFILE '.rokit\bin\rojo.exe'
if (-not (Test-Path $rojo)) { $rojo = 'rojo' }
& $rojo build (Join-Path $cible 'place.project.json') -o (Join-Path $cible "$Nom.rbxl")

# Depot Git local
Push-Location $cible
try {
    git init -b main | Out-Null
    git add .
    git commit -m "Création de $Titre à partir du template" | Out-Null
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "Jeu cree : $cible"
Write-Host "1. Ouvrir $Nom.rbxl dans Studio, puis Fichier > Sauvegarder sur Roblox"
Write-Host "2. Dans $cible : rojo serve, puis plugin Rojo > Connect"
