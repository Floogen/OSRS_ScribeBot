function convertToImgur([string]$imageUri,[string]$postTitle)
{
    #grab client id from our local csv file
    $imgurClientID = (Import-Csv -Path "$PSScriptRoot\imgurAPILogin.csv").imgurClientID
    
    <#
    $credentials = @{
        refresh_token = ""
        grant_type = "refresh_token"
        client_id = $imgurClientID
        client_secret = ""
        }

    $imgurTokenInfo = (Invoke-RestMethod -Method POST -Uri "https://api.imgur.com/oauth2/token" -Body $credentials -ContentType 'application/x-www-form-urlencoded').
    $imgurTokenInfo.access_token
    $imgurTokenInfo.refresh_token
    #>

    #load in the client-id into the header
    $header = @{ 
        Authorization = "Client-ID $imgurClientID"
        }

    #load in the image's url and the title passed in via the function's parameters
    $body = @{
        title = $postTitle
        image = $imageUri
        }
    #attempt to upload the image into imgur
    try
    {
        $imgurPostData = (Invoke-RestMethod -Method POST -Uri "https://api.imgur.com/3/image" -Headers $header -Body $body -DisableKeepAlive -ContentType 'application/x-www-form-urlencoded')
    }
    catch
    {
        Write-Host "Error on posting image to imgur, trying again"
        try
        {
            Start-Sleep -Seconds 30
            $imgurPostData = (Invoke-RestMethod -Method POST -Uri "https://api.imgur.com/3/image" -Headers $header -Body $body -DisableKeepAlive -ContentType 'application/x-www-form-urlencoded')
        }
        catch
        {
            Write-Host "Could not upload to imgur, returning original URI."
            return $imageUri
        }
    }

    #if image upload is successful, parse together the id of the image with the image type and send it back to the request call
    return ("https://i.imgur.com/" + $imgurPostData.data.id + "." + ($imgurPostData.data.type -split 'image/')[1])
}

#convertToImgur -imageUri "http://cdn.runescape.com/assets/img/external/oldschool/2018/newsposts/2018-04-05/max_capes.jpg" -postTitle "F2P PvP world & World Rota"