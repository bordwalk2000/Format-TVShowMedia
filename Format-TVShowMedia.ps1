$url = ''
$HTML = Invoke-WebRequest -Uri $URL -ErrorAction Stop

$results =  $HTML.ParsedHtml.body.getElementsByTagName("div") | Where {$_.classname -like '*list_item*'}

foreach ($episode in $results) {
    $Season_episode = (($episode.childNodes[1].childNodes[1].textContent).Trim()) -split ','
    
    
    #Get Season
    if([int]($Season_episode[0].SubString(1)) -le 10) {
        $Season = 'S0' + $Season_episode[0].SubString(1)
    } else {
        $season = $Season_episode[0].ToUpper()
    }
    
    #Get Episode
    if([int]($Season_episode[0].SubString(1)) -le 10) {
        $episodenumber = '.E0' + $Season_episode[1].Trim().SubString(2)
    } else {
        $episodenumber = '.E' + $Season_episode[1].Trim().SubString(2)
    }
    

    $season + $episodenumber + ' ' + ($episode.childNodes[3].childNodes[5].innerText).Trim()
}


#load_next_episodes