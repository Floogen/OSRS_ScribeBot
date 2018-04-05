function parsePost([string]$postUri)
{
    #big shoutout to [http://redditpreview.com/], as it helped debugging immensely!

    #$postUri = 'http://services.runescape.com/m=news/theatre-of-blood-rewards-tournament-world-feedback-tweaks?oldschool=1' #debugging purposes, keep commented otherwise
    
    #get raw news post
        #we can't seem to use ParsedHtml from WebRequest, either due to PS or how Jagex does their HTML
            #so we'll need to use the UseBasicParsing and parse it ourselves
    $r = Invoke-WebRequest -Uri $postUri -UseBasicParsing -UserAgent "OSRS Web Page Scrapping" -DisableKeepAlive 

    #Jagex uses the following to designate their titles/author/title image (usually)
        #NOTE: you'll see this double split be used often within this script, as Powershell's (v5) ParsedHtml doesn't seem to work properly/at all on Jagex's articles
    $titleContent = (($r.Content -split '<div class="left">')[1] -split '</div>')[0]
    
    $title = (($titleContent -split '<h2>')[1] -split '</h2>')[0]
    $author = (($titleContent -split '<h3>')[1] -split '</h3>')[0]

    if($author -eq "")
    {
        #no author given, as sometimes the news post has no explict author
        $author = "Not Given"
    }
    $date = ([datetime](($titleContent -split '<i>')[1] -split '</i>')[0]).ToLongDateString()

    #grabbing the thumbnail of the news article
    $imageSummaryContent = (($r.Content -split '<div id="osrsSummaryImage">')[1] -split '</div>')[0]
    $titleImage = "[Title Image]("+(($imageSummaryContent -split 'src="')[1] -split '">')[0]+")"
    
    #$parsedArticleText will makeup the Markup body that will be posted
    $parsedArticleText = "#$title`n**Author:** $author  `n**Date:** $date  `n**Thumbnail: $titleImage**`n`n&nbsp;"

    #this particular split will narrow down everything from the Mod's signature at the bottom, to just under the date given in the news post
    $rawArticleText = (($r.Content -split '<div class="osrsArticleContentText">')[1] -split '<img class="widescroll-bottom"')[0]

    #replace all question marks that are followed by a character with an apostrophe
        #we have to do this because the character seems to be unreadable via Powershell from the WebRequest call

    #quick and dirty way to get the characters encoded into ASCII
    $rawArticleText | Out-File -encoding ASCII "$PSScriptRoot\tempHolder.txt"
    $rawArticleText = ((Get-Content -Path "$PSScriptRoot\tempHolder.txt") -replace "([a-z]+)\?([a-z]+)",'$1''$2') | Out-String
    Remove-Item  "$PSScriptRoot\tempHolder.txt" -Force

    #now the messy park, we're scrub through the HTML tags and translate them into Markup (where applicable)
        #an explanation for the following: <tagName>\s? is replaced the designated tag with an optional replace of space in front or back of the string
            #the reason for this is Markup breaks if there is any spacing between their markers (for example *test* will work but *test * will not)

    #spacing/formatting replacements
    $rawArticleText = ($rawArticleText -replace '<p>',"`n`n")
    $rawArticleText = ($rawArticleText -replace '</p>',"&nbsp;`n")
    $rawArticleText = ($rawArticleText -replace '</br>',"`n`n")
    $rawArticleText = ($rawArticleText -replace '<br\s?/>',"&nbsp;`n`n&nbsp;")
    $rawArticleText = ($rawArticleText -replace '<br>',"`n`n")
    $rawArticleText = ((($rawArticleText -replace '[\s].*<font.*?>',"`n#") -replace '</font></center>',"`n`n")) #-replace '[\s]?#','#'
    #end of spacing/formating replacements


    #using regex to pull out the URL and the hypertext, via named capture groups
    $rawArticleText = (($rawArticleText -replace '<a href="(.*?)">(.*?)</a>','[$2]($1)')) -replace "http([^\s]+[^'])'([^\s?])",'http$1?$2'


    #image formatting starts below

    #using regex to filter and grab the image links
    [regex]$filter = '<img src=".*'

    #foreach match against the filter, iterate through it
    $imageCounter = 1
    foreach($imgLink in ($filter.Matches($rawArticleText) | ForEach-Object {$_.Value}))
    {
        #formating the link to fit with Markup (added image numbering to help see what images are where)
        $replacementLink = ""
        #$replacementLink = (($imgLink -replace '<img src="',("[Image \#"+($imageCounter)+"](")) -replace '"*/>',")`n`n")
        $replacementLink = (($imgLink -replace '<img src="',("[Image \#"+($imageCounter)+"](")) -split '"')[0]+")"+((($imgLink -replace '<img src="',("[Image \#"+($imageCounter)+"](")) -split '"/>')[1])

        if($replacementLink -match "/hr.png")
        {
            #"hr.png" is a divider picture that you'll see in the news post
                #to better fit Reddit, I replaced any instances of that image with Markup's border
            $rawArticleText = ($rawArticleText -replace $imgLink,"---")
        }
        else
        {
            #unique image, add it to the raw Markup body
            $rawArticleText = ($rawArticleText -replace $imgLink,$replacementLink)
            #increment the image counter for unique images
            $imageCounter++
        }
        #replace the old image link with the Markup version
    }
    #end of image formatting

    #text style replacements
    $rawArticleText = (($rawArticleText -replace '<em>[\s]+','*') -replace "[\s]+</em>",'*')
    $rawArticleText = (($rawArticleText -replace '<em>\s?','*') -replace '\s?</em>','*')

    $rawArticleText = (($rawArticleText -replace '<i>[\s]+','*') -replace "[\s]+</i>",'*')
    $rawArticleText = (($rawArticleText -replace '<i>\s?','*') -replace "\s?</i>",'*')

    $rawArticleText = (($rawArticleText -replace '<b>[\s]+','**') -replace '[\s]+</b>','**')
    $rawArticleText = (($rawArticleText -replace '<b>\s?','**') -replace '\s?</b>','**')

    $rawArticleText = (($rawArticleText -replace '<strong>[\s]+','**') -replace '[\s]+</strong>','**')
    $rawArticleText = (($rawArticleText -replace '<strong>\s?','**') -replace '\s?</strong>','**')

    $rawArticleText = (($rawArticleText -replace '<s>[\s]+','~~') -replace '[\s]+</s>','~~')
    $rawArticleText = (($rawArticleText -replace '<s>\s?','~~') -replace '\s?</s>','~~')

    $rawArticleText = (($rawArticleText -replace "<li>([^`n]+)",("`n- " + '$1'+"`n`n")) -replace '\s?</li>',"&nbsp;`n`n")
    
    $rawArticleText = (($rawArticleText -replace '<h2>\s?','##') -replace '\s?</h2>','')
    $rawArticleText = (($rawArticleText -replace '<h3>\s?','###') -replace '\s?</h3>','')
    $rawArticleText = (($rawArticleText -replace '<h4>\s?','####') -replace '\s?</h4>','')
    $rawArticleText = (($rawArticleText -replace '<h5>\s?','#####') -replace '\s?</h5>','')
    $rawArticleText = (($rawArticleText -replace '<h6>\s?','######') -replace '\s?</h6>','')
    #end of text style replacements

    #table formating

    #regex to grab everything in between the table tags
    [regex]$pattern = '(?s)<table.*?>(.*?)</table>'
    foreach($table in ($pattern.Matches($rawArticleText) | ForEach-Object {$_.Value}))
    {
        #defines the markup table structure
        $tableStruct = ""
        #defines the alignment (will always be center aligned)
        $alignmentStruct = ""
        $headerCount = 0
        $columnCount = 0

        #regex to grab all the table header tags under this specific table
        [regex]$tabPattern = '(?s)<th.*?>(.*?)</th>'
        foreach($tabHeader in ($tabPattern.Matches($table) | ForEach-Object {$_.Value}))
        {
            $tableStruct += (($tabHeader -replace '\s?\s?<th>\s?','') -replace '</th>',"|") -replace '</th>',"`t"
            $alignmentStruct += ":---:|"
            $headerCount += 1
        }
        $tableStruct = $tableStruct + "`n" + $alignmentStruct + "`n"

        #regex to grab all the table data tags under this specific table
        [regex]$tabPattern = '(?s)<td.*?>(.*?)</td>'
        foreach($tabEntry in ($tabPattern.Matches($table) | ForEach-Object {$_.Value}))
        {
            $currentCell = $tabEntry
            #replace any carriage returns with spaces
            if($currentCell -match "[\n\r]")
            {
                $currentCell = $tabEntry -replace "[\n\r]"," "
            }

            #if the current column count is >= to the amount of headers, move to first column in a new row after appending the data
            if($columnCount -ge $headerCount - 1)
            {
                $tableStruct += ((($currentCell -replace '\s?<td>[\n\r]?','') -replace "`n","`t") -replace '</td>',"|`n")
                $columnCount = 0
            }
            else
            {
                #append data to next column
                $tableStruct += ((($currentCell -replace '\s?<td>','') -replace "`n","`t") -replace '</td>',"|")
                $columnCount += 1
            }
            
        }
        #replace the selected table with the newly parsed (for Markup) table
        $rawArticleText = $rawArticleText.Replace($table,$tableStruct)
    }
    #end of table formatting

    #removes all leftover tags that aren't being handled
    $rawArticleText = ($rawArticleText -replace '<[^>]+>','')

    #removes any excess tabs, as it appears the raw HTML may have unwanted tabs inserted in front of where the tags may have been
    $rawArticleText = ($rawArticleText -replace "`t",'')

    #append the raw (now parsed text) to the main Markup body
    $parsedArticleText += $rawArticleText

    #append bot information
    $parsedArticleText += "`n`n&nbsp;`n`n---`n`nHi, I'm your friendly neighborhood OSRS bot.  `nI tried my best to parse this newsletter. If you have any feedback, please do let me know [here](https://www.reddit.com/user/OSRS_ScribeBot/comments/889onq/give_feedbacksuggestions_here/?ref=share&ref_source=link)!  `nInterested to see how I work? See my post [here](https://www.reddit.com/user/OSRS_ScribeBot/comments/89ggpr/osrs_scribebots_github_repository/?ref=share&ref_source=link) for my GitHub repo!"

    #return the now parsed Markup text
    return $parsedArticleText
}