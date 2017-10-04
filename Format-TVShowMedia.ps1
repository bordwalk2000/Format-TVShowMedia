<#
.SYNOPSIS
 
.DESCRIPTION

 
.PARAMETER FolderPath
Specifiy the path to the folder where the files are located that need to be renamed and organised.
 
.PARAMETER URL

.EXAMPLE

.NOTES
    Author: Bradley Herbst
    Version: 0.1
    Last Updated: October 3, 2017
        
    ChangeLog
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $FolderPath,
    [string] $url
)


    BEGIN {

function Get-IMDBTVShowSeasonEpisodes { 
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)][string] $url
    )

    $HTML = Invoke-WebRequest -Uri $URL -ErrorAction Stop
    $results =  $HTML.ParsedHtml.body.getElementsByTagName("div") | Where {$_.classname -like '*list_item*'}

    foreach ($episode in $results) {
        $Season_episode = (($episode.childNodes[1].childNodes[1].textContent).Trim()) -split ','
        $EpisodeName = 'S{0:D2}' -f [int]$Season_episode[0].SubString(1) + '.E{0:D2}' -f [int]$Season_episode[1].Trim().SubString(2) + ' ' + ($episode.childNodes[3].childNodes[5].innerText).Trim()
        
        Write-Output $EpisodeName 
    }
}


function Get-IMDBTVShowSeasons { 
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)][string] $url
    )

    $HTML = Invoke-WebRequest -Uri $URL -ErrorAction Stop
    $results =  $HTML.ParsedHtml.body.getElementsByTagName("div") | Where {$_.classname -like '*seasons-and-year-nav*'}
    
    foreach ($season in $results.childNodes[7].innerHTML.trim() -Split(“`n”)) {
        $props = @{
            'Season' = (($season -split '>')[1]).Substring(0,1);
            'URL' = 'http://www.imdb.com/' + ($season.TrimStart('<a href="/') -split ';')[0];
        }

        New-Object -TypeName PSObject -Property $props
    }
}

    }

    PROCESS {
    
If (!$url) {
    #Remove parents folders from the Folder path, then stores the working folder in its own variable.
    $FolderName = Split-Path $FolderPath -leaf

    #Replaces the spaces in the string to + signs to be used in the search query
    $SearchString = $FolderName.replace(' ','+')

    #Places the SerachString into the Search URL to be Used
    $SearchQuery = "http://www.imdb.com/find?ref_=nv_sr_fn&q=$SearchString&s=all"

    #Search for the course name and pulls the top result.
    $HTML = Invoke-WebRequest -Uri $SearchQuery 
    $results = $HTML.ParsedHtml.body.getElementsByTagName("table") | Where{$_.classname -eq 'findList'} | 
    foreach{$_.getElementsByTagName("tr") | Where{$_.classname -like '*findResult*'}} | Select -First 1

    $url = 'http://www.imdb.com/' + (($results.innerHTML -split '<td class="result_text">')[1].TrimStart('<a href="/') -split '"')[0]

}


Get-IMDBTVShowSeasons -url $url | Sort Season | 
% {
    #Create Season Folder if it doesn't exisist
    if(!(Test-Path -Path ("$FolderPath\Season {0:D2}" -f ([int]$_.Season)))){New-Item -ItemType directory -Path ("$FolderPath\Season {0:D2}" -f ([int]$_.Season))}
    
    Get-IMDBTVShowSeasonEpisodes -url $_.url | 
    % {
       #Looks for files in the $FoldePath Directory and sub directories that are the file extension spcified in the params.
        Get-ChildItem -Path $FolderPath -Filter "*" -Recurse | 
        #$TitleName -match "S(?<season>\d{1,2}).(\s*)E(?<episode>\d{1,2})|Season(\d{1,2}).(\s*)Episode(\d{1,2})"
    }
}
 
#Looks for folders with no files in them and then deletes the files if any were found.
Get-ChildItem -Path $FolderPath -recurse | Where {$_.PSIsContainer -and @(Get-ChildItem -Lit $_.Fullname -r | 
Where {!$_.PSIsContainer}).Length -eq 0} |
Remove-Item -recurse

    }

