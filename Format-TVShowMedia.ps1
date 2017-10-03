function Get-IMDBTVShowSeasonEpisodes { 
    [cmdletbinding()]
    param(
        [Parameter(Mandatory,
               ValueFromPipeline,
               ValueFromPipelineByPropertyName)]
        [string] $url
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
        [Parameter(Mandatory,
               ValueFromPipeline,
               ValueFromPipelineByPropertyName)]
        [string] $url
    )

    $HTML = Invoke-WebRequest -Uri $URL -ErrorAction Stop
    $results =  $HTML.ParsedHtml.body.getElementsByTagName("div") | Where {$_.classname -like '*seasons-and-year-nav*'}
    
    foreach ($season in $results.childNodes[7].innerHTML.trim() -Split(“`n”)) {
        $props = @{
            'Season' = (($season -split '>')[1]).Substring(0,1);
            'URL' = 'http://www.imdb.com/' +($season.TrimStart('<a href="/') -split ';')[0];
        }

        New-Object -TypeName PSObject -Property $props
    }
}


Get-IMDBTVShowSeasons -url '' | Sort Season | 
% {
 
    Get-IMDBTVShowSeasonEpisodes -url $_.url
 
 }
