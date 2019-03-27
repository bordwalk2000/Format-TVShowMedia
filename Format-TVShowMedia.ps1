<#
.SYNOPSIS
Renames TV Show files to a specific naming scheme and moves the files to their correct seasons folder.

.DESCRIPTION
The scrips grabs data from IMDB, creates a Season folder for the season it's on, unless one already exists.  Renames the tv shows episodes to the
the required naming scheme and then moves the tv shows episodes for that season into the correct seasons folder, and then moves onto the next season.
After it finishes processing all the seasons empty folders are then removed.

.PARAMETER FolderPath
Specify the path to the folder where the files are located that need to be renamed and organized.

.PARAMETER URL
URL to the main page for the TV Show located at IMDB.com.  The script will then use this URL for grabbing the data instead of trying to find it on its own.

.EXAMPLE
PS C:\> Format-TVShowMedia -FolderPath "C:\Folder"
PS C:\> Format-TVShowMedia -FolderPath "C:\Folder" -URL "http://www.imdb.com/title/tt0108778/?ref_=fn_al_tt_1"

.NOTES
    Author: Bradley Herbst
    Version: 2.1
    Last Updated: July 11th, 2018

    ChangeLog
    1.0 - 2017-10-05
        Initial Release
    1.1 - 2017-11-09
        Verifies that TV Show title name doesn't have any special characters that would interfere with file renaming.
    1.2 - 2017-11-13
        Suppressed errors in the Get-IMDBTVShowSeasonEpisodes function for episodes fetched from IMDB that haven't aired yet.
    2.0 - 2018-07-11
        IMDB changed their website enough to break the script.  Updated the script to fix those corrections.
    2.0.1 - 2019-03-26
        Cleaning up code formating.  Code Layout & Changing a few double quotes to single quotes.
    2.1 - 2019-03-27
        TV Show first aired year added to TV Show folder name.

Use the following to recreate tv show folder structure so you can verify the scirpt will work the way you want it to before running in on your real files.
param([Parameter(Mandatory)][string] $SourceBackupFolder)
New-Item -ItemType Directory -Path $(Split-Path $SourceBackupFolder -Leaf)
Get-ChildItem -Path $SourceBackupFolder -Recurse |
ForEach-Object {
    if($_.Gettype().Name -eq 'DirectoryInfo'){
        New-Item -Name $_.BaseName -ItemType Directory -Path C:\#Tools\$($_.Parent)}
    else{
        New-Item -Name $_.Name -Path $(Split-Path $_.Directory -leaf)
    }
}
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $FolderPath,
    [string] $url
)


BEGIN {

    function Get-IMDBTVShowTitle {
        [cmdletbinding()]
        param(
            [Parameter(Mandatory)][string] $url
        )

        $HTML = Invoke-WebRequest -Uri $url -ErrorAction Stop
        $titlewrapper = $HTML.ParsedHtml.body.getElementsByTagName('div') | Where-Object {$_.classname -like '*title_wrapper*'}
        
        $title = ($titlewrapper.getElementsByTagName('h1') | Select-Object -ExpandProperty innerText).trim()
        $date = ($titlewrapper.textContent.trim()).split(' | ')[-2].trim('(').split('–')[0]

        Write-Output "$title ($date)"
    }

    function Get-IMDBTVShowSeasons {
        [cmdletbinding()]
        param(
            [Parameter(Mandatory)][string] $url
        )

        $HTML = Invoke-WebRequest -Uri $URL -ErrorAction Stop
        $Results = $HTML.ParsedHtml.body.getElementsByClassName('seasons-and-year-nav')
        $SeasonsList = (($Results | Select-Object -expand innerhtml) -split ('<div>') -split ('&nbsp;&nbsp;') | Where-Object {$_ -like '*season=*' -or $_ -like '*tt_eps_sn_mr*'}).trim()

        if ($SeasonsList -like '*tt_eps_sn_mr*') {
            $URL = 'https://www.imdb.com/' + (($SeasonsList -like '*tt_eps_sn_mr*').TrimStart('<A href="/') -split '"')[0]
            $HTML = Invoke-WebRequest -Uri $URL -ErrorAction Stop
            $Results = (((($HTML.ParsedHtml.body.getElementsByClassName('episode-list-select') | Select-Object -ExpandProperty textContent) -split '  OR  ')[0]).trimStart('Season: ') -split (' ')).trim()
            $SeasonURL = 'https://www.imdb.com/' + ((($SeasonsList.TrimStart('<A href="/') -split ';')[0]) -split '=')[0] + '='

            foreach ($Season in $Results) {
                $props = @{
                    'Season' = $season
                    'URL'    = $SeasonURL + $season
                }
                New-Object -TypeName PSObject -Property $props
            }

        }
        else {
            foreach ($Season in (($Results | Select-Object -expand innerhtml) -split ('<div>') -split ('&nbsp;&nbsp;') | Where-Object {$_ -like '*season=*' -or $_ -like '*tt_eps_sn_mr*'}).trim()) {
                $props = @{
                    'Season' = (($Season -split '>')[1]).Substring(0, 1)
                    'URL'    = 'https://www.imdb.com/' + ($Season.TrimStart('<A href="/') -split ';')[0]
                }
                New-Object -TypeName PSObject -Property $props
            }
        }
    }

    function Get-IMDBTVShowSeasonEpisodes {
        [cmdletbinding()]
        param(
            [Parameter(Mandatory)][string] $url
        )

        $HTML = Invoke-WebRequest -Uri $URL -ErrorAction Stop
        $Results = $HTML.ParsedHtml.body.getElementsByTagName('div') | Where-Object {$_.classname -like '*list_item*'}

        try {
            foreach ($Episode in $Results) {
                $SeasonEpisode = ($Episode.childNodes[0].childNodes | Select-Object -ExpandProperty InnerText) -split ',' -replace '\D+(\d+)', '$1'
                $EpisodeName = 'S{0:D2}' -f [int]$SeasonEpisode[0] + '.E{0:D2}' -f [int]$SeasonEpisode[1] + ' ' + ($Episode.childNodes[0].childNodes | Select-Object -ExpandProperty Title).Trim()

                Write-Output $EpisodeName
            }
        }
        catch {}
    }
}

PROCESS {

    If (!$url) {
        #Remove parents folders from the Folder path, then stores the working folder in its own variable.
        $FolderName = Split-Path $FolderPath -leaf

        #Replaces the spaces in the string to + signs to be used in the search query
        $SearchString = $FolderName.replace(' ', '+')

        #Places the SerachString into the Search URL to be Used
        $SearchQuery = "https://www.imdb.com/find?ref_=nv_sr_fn&q=$SearchString&s=all"

        #Search for the TV Show and pulls URL from the top result.
        $HTML = Invoke-WebRequest -Uri $SearchQuery -ErrorAction Stop
        $Results = $HTML.ParsedHtml.body.getElementsByTagName('table') | Where-Object {$_.classname -eq 'findList'} |
            ForEach-Object {
            $_.getElementsByTagName('tr') | Where-Object {$_.classname -like '*findResult*'}} | Select-Object -First 1

        $url = 'https://www.imdb.com/' + (($Results.innerHTML -split '<td class=result_text>')[-1] -split '"')[1]
    }

    $IllegalChars = [string]::join('', ([System.IO.Path]::GetInvalidFileNameChars())) -replace '\\', '\\'
    $ParentFolderTitle = (Get-IMDBTVShowTitle -url $url) -replace "[$IllegalChars]", ''
    $TVShowTitle = $ParentFolderTitle.split(' ')[0]
    
    Rename-Item -Path  $FolderPath -NewName $ParentFolderTitle
    $FolderPath = (Split-Path -Path $FolderPath -Parent) + "\$ParentFolderTitle"

    Get-IMDBTVShowSeasons -url $url | Sort-Object Season |
        ForEach-Object {
        #Create Season Folder if it doesn't exisist
        if (!(Test-Path -Path ("$FolderPath\Season {0:D2}" -f ([int]$_.Season)))) {New-Item -ItemType Directory -Path ("$FolderPath\Season {0:D2}" -f ([int]$_.Season))}

        Get-IMDBTVShowSeasonEpisodes -url $_.url |
            ForEach-Object {
            $EpisodeNumber = ($_ -split ' ')[0]
            $EpisodeTitle = $_ -replace "[$IllegalChars]", ''

            Get-ChildItem -Path $FolderPath -File -Recurse |
                Where-Object {
                ($_.Name -match ($EpisodeNumber -split '\.')[0] `
                        -and $_.Name -match ($EpisodeNumber -split '\.')[1])
            } |
                Rename-Item -NewName {$TVShowTitle + ' ' + $EpisodeTitle + $_.extension} -ErrorAction Continue

            #Looks for files with the correct chapter and title number in all folders and them moves them to their correct chapter folder
            Get-ChildItem -Path $FolderPath -File -Recurse |
                Where-Object { 
                ($_.Name -match ($EpisodeNumber -split '\.')[0] `
                        -and $_.Name -match ($EpisodeNumber -split '\.')[1]) `
                    -or ($_.Name -match 'S{0:D1}' -f [int]($EpisodeNumber -split '\.')[0].Substring(1) `
                        -and $_.Name -match 'E{0:D1}' -f [int]($EpisodeNumber -split '\.')[1].Substring(1))
            } |
                Move-Item -Destination ("$FolderPath\Season {0:D2}" -f ([int]$_.Substring(1, 2)))
        }
    }

    #Looks for folders with no files in them and then deletes the files if any were found.
    Get-ChildItem -Path $FolderPath -recurse | 
        Where-Object {$_.PSIsContainer -and @(Get-ChildItem -Lit $_.Fullname -r | Where-Object {!$_.PSIsContainer}).Length -eq 0} |
        Remove-Item -Recurse
}

