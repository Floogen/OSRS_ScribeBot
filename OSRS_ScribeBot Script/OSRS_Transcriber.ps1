#networking related, for use in Invoke-Webrequest/RestMethod
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[System.Net.ServicePointManager]::DnsRefreshTimeout = 0

$netAssembly = [Reflection.Assembly]::GetAssembly([System.Net.Configuration.SettingsSection])

if($netAssembly)
{
    $bindingFlags = [Reflection.BindingFlags] "Static,GetProperty,NonPublic"
    $settingsType = $netAssembly.GetType("System.Net.Configuration.SettingsSectionInternal")

    $instance = $settingsType.InvokeMember("Section", $bindingFlags, $null, $null, @())

    if($instance)
    {
        $bindingFlags = "NonPublic","Instance"
        $useUnsafeHeaderParsingField = $settingsType.GetField("useUnsafeHeaderParsing", $bindingFlags)

        if($useUnsafeHeaderParsingField)
        {
          $useUnsafeHeaderParsingField.SetValue($instance, $true)
        }
    }
}
#end of network related calls

#will eventually convert parsePost function into a module, but for now it will just be a seperate .ps1 and imported to utilize it's function
. "$PSScriptRoot\Parse-OSRSPost.ps1"

#function get token from reddit to utilize the api
function Get-RedditToken 
{
    $credentials = @{
    grant_type = "password"
    username = $Global:username
    password = $Global:password
    }
    $Global:token = Invoke-RestMethod -Method Post -Uri "https://www.reddit.com/api/v1/access_token" -Body $credentials -ContentType 'application/x-www-form-urlencoded' -Credential $Global:creds
}

#get token from local .txt
    #then check if it's valid, if not use function
$token = $null
try
{
    $token = (Import-Csv -Path "$PSScriptRoot\tokenCache.csv") 
}
catch
{
    Write-Host "Cached token doesn't exist..."
    Get-RedditToken
}

#import local Reddit API cred .csv file
$credFile = Import-Csv -Path "$PSScriptRoot\redditAPILogin.csv"

#load in creds to obscure them
$username = $credFile.redditUser
$password = $credFile.apiRedditBotPass
$clientID = $credFile.clientID
$clientSecret = ConvertTo-SecureString ($credFile.clientSecret) -AsPlainText -Force
$creds = New-Object -TypeName System.management.Automation.PSCredential -ArgumentList $clientID, $clientSecret
 
#authorization header
$header = @{ 
    authorization = $token.token_type + " " + $token.access_token
    }

#check if cached token is valid
try
{
    Invoke-RestMethod -uri "https://oauth.reddit.com/user/$username" -Headers $header -UserAgent "User Agent - OSRS_Scribebot Token Script"
}
catch
{
    Write-Host "Token expired, renewing..." -ForegroundColor Red
    Get-RedditToken #updates token value
    $header = @{ 
    authorization = $token.token_type + " " + $token.access_token
    }
    Write-Host "Renewed Access Code." -ForegroundColor Green
}

#have a search limit of the latest 100 posts on the 2007scape reddit
$payload = @{
            limit = '100'
            }

#attempt to search the new posts, if fails reattempt to get token (as it may have expired)
    #TO DO: rewrite this for smarter error checking, but in most cases it will be the token expiring
    #since the script is running once per minute to check against new posts (and there doesn't seem to be a way to check when a token will expire other than tracking it yourself)
        #we'll just do a lazy try-catch for each API call

$searchBlock = $null
try
{
    $searchBlock = Invoke-RestMethod -uri "https://oauth.reddit.com/r/2007scape/new" -Method Get -Headers $header -Body $payload -UserAgent "User Agent - OSRS_Scribebot PS Script"
}
catch
{
    Write-Host "Token expired, renewing..." -ForegroundColor Red
    Get-RedditToken #updates token value
    $header = @{ 
    authorization = $token.token_type + " " + $token.access_token
    }
    Write-Host "Renewed Access Code." -ForegroundColor Green
    
    $searchBlock = Invoke-RestMethod -uri "https://oauth.reddit.com/r/2007scape/new" -Method Get -Headers $header -Body $payload -UserAgent "User Agent - OSRS_Scribebot PS Script"
}

#only do one at a time for now, to prevent time-out issues
    #TO DO: rewrite this lazy band-aid fix
        #band-aid fix needed to prevent issues where multiple people post the same link at a time, causing issues with the script

#first pass flag
$firstPass = $true

foreach($newsLink in ($searchBlock.data.children.data | Where {$_.saved -eq $false -and ($_.url -match "http://services.runescape.com/m=news" -or $_.url -match "https://services.runescape.com/m=news")}))
{
    if($firstPass)
    {
        #first pass has been attempted, set flag to false
        $firstPass = $false

        #Save this post to prevent further touches
            #this script caches post via Reddit's save function, as we can check if a news post is saved
                #once we touch a script, we save it and ignore it in the next pass

        Write-Host "Caching and posting to" $newsLink.title
        $payload = @{
                category = "cached"
                id = $newsLink.name

                }
        $saveBlock = Invoke-RestMethod -uri "https://oauth.reddit.com/api/save" -Method POST -Headers $header -Body $payload -UserAgent "User Agent - OSRS_Scribebot PS Script"

        #call parser method
        $parsedText = $null
        $parsedText = (parsePost -postUri $newsLink.url)

        #now grab their posted news link and post ID
        $targetID = $newsLink.name

        #if the post is larger than 9500, split it into multiple posts and comment them below one another
            #we must do this in order to get around the 10,000 character limit on Reddit
            #I do a 9500 check as I append some information to the end of the posts (bot info)
        if($parsedText.Length -gt 9500)
        {
            #get the count for how many times we need to cut up the news post
            $divCount = [math]::Round(($parsedText.Length / 9000))

            #find nearest newline to seperate
            $index = 0
            for($x = 0; $x -le $divCount; $x++)
            {
                if($parsedText.Length -gt 9000)
                {
                    $index = $parsedText.Substring(0,9000).lastIndexOf([Environment]::Newline)
                    
                    #create post via this payload below (partial post) to targeted post/comment
                    $payload = @{
                    api_type = "json"
                    text = ($parsedText.Substring(0,$index) + "`n`n **(continued below)**") #this gets you first post
                    thing_id= $targetID
                    }
                
                    try
                    {
                        $postInfo = Invoke-RestMethod -uri "https://oauth.reddit.com/api/comment" -Method Post -Headers $header -Body $payload -UserAgent "User Agent - OSRS_Scribebot PS Script"
                    }
                    catch
                    {
                        Write-Host "Token expired, renewing..." -ForegroundColor Red
                        Get-RedditToken #updates token value
                        $header = @{ 
                        authorization = $token.token_type + " " + $token.access_token
                        }
                        Write-Host "Renewed Access Code." -ForegroundColor Green
    
                        $postInfo = Invoke-RestMethod -uri "https://oauth.reddit.com/api/comment" -Method Post -Headers $header -Body $payload -UserAgent "User Agent - OSRS_Scribebot PS Script"
                    }

                    #get ID of newly made comment, so that we can post to it again
                    $targetID = $postInfo.json.data.things.data.name

                    #trim the post starting from where we cut it
                    $parsedText = $parsedText.Substring($index)
                }
                else
                {
                    #the leftover parsedText is now enough for a single post
                    $payload = @{
                    api_type = "json"
                    text = $parsedText #last post
                    thing_id= $targetID
                    }
                
                    try
                    {
                        $postInfo = Invoke-RestMethod -uri "https://oauth.reddit.com/api/comment" -Method Post -Headers $header -Body $payload -UserAgent "User Agent - OSRS_Scribebot PS Script"
                    }
                    catch
                    {
                        Write-Host "Token expired, renewing..." -ForegroundColor Red
                        Get-RedditToken #updates token value
                        $header = @{ 
                        authorization = $token.token_type + " " + $token.access_token
                        }
                        Write-Host "Renewed Access Code." -ForegroundColor Green
    
                        $postInfo = Invoke-RestMethod -uri "https://oauth.reddit.com/api/comment" -Method Post -Headers $header -Body $payload -UserAgent "User Agent - OSRS_Scribebot PS Script"
                    }
                }
            }
    
        }
        else
        {
            #post is small enough for a single post
            $payload = @{
            api_type = "json"
            text = $parsedText
            thing_id= $targetID
            }
                    try
                    {
                        $postInfo = Invoke-RestMethod -uri "https://oauth.reddit.com/api/comment" -Method Post -Headers $header -Body $payload -UserAgent "User Agent - OSRS_Scribebot PS Script"
                    }
                    catch
                    {
                        Write-Host "Token expired, renewing..." -ForegroundColor Red
                        Get-RedditToken #updates token value
                        $header = @{ 
                        authorization = $token.token_type + " " + $token.access_token
                        }
                        Write-Host "Renewed Access Code." -ForegroundColor Green
    
                        $postInfo = Invoke-RestMethod -uri "https://oauth.reddit.com/api/comment" -Method Post -Headers $header -Body $payload -UserAgent "User Agent - OSRS_Scribebot PS Script"
                    }
        }
    }
}


#export latest token to local csv file
$token | Export-Csv -Path "$PSScriptRoot\tokenCache.csv" -NoTypeInformation