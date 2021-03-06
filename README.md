# OSRS_ScribeBot
[Reddit Bot] **Powershell** script that parses Jagex's news post into Markup that are linked on Reddit utilizing their API.

# How It Works
1. The script is scheduled to check [/r/2007scape/](https://www.reddit.com/r/2007scape/new) every minute for new posts with a [OSRS news link](http://services.runescape.com/m=news/).
2. After finding a match, the script caches the post via Reddit's save function (the script will then ignore it in future passes, as it ignores all saved posts).
3. With the newly saved match, the script then calls the parsing method (Parse-OSRSPost) and converts it from HTML to Reddit's Markup language.
	- I'd highly advise you read the comments on [Parse-OSRSPost](https://github.com/Floogen/OSRS_ScribeBot/blob/master/OSRS_ScribeBot%20Script/Parse-OSRSPost.ps1), as this particular step makes up the majority of the script's functionality.
4. Finally, the script posts the Markup-formatted news post onto the matched Reddit post.
	- If the post is larger than Reddit's allowed limit (10,000 characters), then the script splits it into several fragments and comments them below one another.

# Questions?
I commented the script pretty thoroughly, but some things may be confusing to read even with explanations (especially the regex). However, if you have any questions about how my code works, please do let me know and I'll try to explain where I can. I'd advise Googling your question first however, as that often will answer things faster than I can.

# To-do List
- [ ] Move away from ASCII and towards UTF8, to better handle special characters in news post (such as in [here](http://services.runescape.com/m=news/price-increase-june-4th-2018?oldschool=1))
- [x] Corrected formatting issues Markup's bold, italic and strikethroughs. Should no longer have missed formatting or leftover Markup characters.
- [x] Release this repo to the public.
- [x] Implement Imgur's REST API to store Jagex's local image files and make them more available to viewers.

# Notes
* **Big** shout-out to [RedditPreview](http://redditpreview.com/) as it helped immensely with debugging the Markup formatting!
* If you'd like to look into Reddit's API, check out their development information [here](https://www.reddit.com/dev/api/).
