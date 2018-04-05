# OSRS_ScribeBot
[Reddit Bot] Parses Jagex's news post into Markup that are linked on Reddit.

# How It Works
1. The script is scheduled to check [/r/2007scape/](https://www.reddit.com/r/2007scape/new) every minute for new posts with a https://services.runescape.com/m=news/ link.
2. After finding a match, the script caches the post via Reddit's save function (the script will then ignore it in future passes, as it ignores all saved posts).
3. With the newly saved match, the script then calls the parsing method (Parse-OSRSPost) and converts it from HTML to Reddit's Markup language.
	- I'd highly advise you read the comments on [Parse-OSRSPost](OSRS_ScribeBot/OSRS_ScribeBot Script/Parse-OSRSPost.ps1), as this particular step makes up the majority of the script's functionality.
4. Finally, the script posts the Markup-formatted news post onto the matched Reddit post.
	- If the post is larger than Reddit's allowed limit (10,000 characters), then the script splits it into several fragments and comments them below one another.

# Questions?
I commented pretty thoroughly, but some things may be confusing to read even with explanations (especially the regex). However, if you have any questions about how my code works, please do let me know and I'll try to explain where I can. I'd advise Googling your question first however, as that often will answer things faster than I can.

# Notes
* **Big** shout-out to [RedditPreview](http://redditpreview.com/) as it helped immensely with debugging the Markup formatting!
* If you'd like to look into Reddit's API, check out their development information [here](https://www.reddit.com/dev/api/).
