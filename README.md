# Arcade Game Launcher

A simple game launcher meant as a frontend for an arcade cabinet. Especially useful for showcasing a bunch of games from game jams. 

It is primarly used by Calgary Game Developer Association (https://www.calgary.games) for their arcade cabinets. 

<p align="center">
  <img src="media/launcher_v0.0.1.gif">
</p>

## Adding Your Game

This is the most important section for devs and teams who want to put their game on the launcher. 
It is important to note that you do not need this launcher to test your game, but it is recommended.
You need to create a **config.ini** for your game like this:

```
[GAME]
title = "Game Title"
executable = "Game Executable.exe"
capsule = "Game Capsule.png"
background = "Game Background.png"
description = "Here is a text blurb.\nDescription of your game."
date_added = "15-01-2025"

[SETTINGS]
visible = true

[ATTRIBUTES]
singleplayer = false
multiplayer = true
coop = true
pvp = true
leaderboards = false
trackball = false

```

Here is a longer example with additional/optional settings, plus comments:

```
[GAME]
title = "Game Title"
executable = "Game Executable.exe"
capsule = "Game Capsule.png"
background = "Game Background.png"
description = "Here is a text blurb.\nDescription of your game."
arguments = "--fullscreen --keyboard"  # optional arguments to pass to your game executable
date_added = "15-01-2025"  # optional date when your game was added
qr = "QR Image.png"  # optional QR code image that can be displayed by the game

[SETTINGS]
visible = true  # a quick way to hide misbehaving game
available = true  # tells the launcher to load/not load

[ATTRIBUTES]
singleplayer = false
multiplayer = true
coop = true
pvp = true
leaderboards = false
trackball = false

```


## How to add setup the launcher with a list of games

1. If not present, create a folder called **games** next to the executable.
2. Inside, create a folder for each game you want. The name of the folder will be the name of the game.
3. Place your executable, capsule image, background image and description.txt
4. The game executable will be launched by the launcher
5. The capsule must be named **capsule** with the following extensions supported: jpg, jpeg, png
6. The background image bust be named **bg** with the following extensions supported: jpg, jpeg, png
7. In **description.txt**, put the description you want to see below your game capsule in the launcher
8. In the optional **config.ini** you can override the above values and add more details (see Game Config section below).
9. You may manually add games to the **launcher.ini** file (optional, see Launcher Config section below).

Here's an example folder  
game_launcher.exe  
├── games  
│   ├── Game name  
│   │   ├── game_executable.exe  
│   │   ├── capsule.jpg  
│   │   └── bg.jpg  
│   │   └── config.ini


## How to navigate

Navigate using keyboard or gamepad using the usual keys used for navigation (arrows keys, enter).

`Alt+Enter` to toggle fullscreen

## Limitations

Right now, the launcher only supports Windows and Linux. 

## Launcher Config

Example of an INI config file for the launcher app. 

```
[LAUNCHER]
title = "My Launcher"
autoscan = true
check_for_updates = true
verbose = true
verbose_console = false
platform = "linux"
enforce_platform = false
show_categories = false
show_version = true
overlay = "an-overlay-image.png"
show_qr_codes = true

[AUTOMATION]
autoscroll = true
autoscroll_time = 5
autoscroll_start_time = 45
screensaver = true
screensaver_title = "My Arcade"
screensaver_time = 300
screensaver_image = "my-screensaver.png"

# GAMES are optional, and can be written in this format:
#  id = "/path/to/game"
[GAMES]
game_1 = "/home/user/Games/arcade-game-launcher/games/chore4b"
```

All keys are optional. See source code to explain each key. Detected values will override any values set in the editor. The "id" key/value for the GAMES section is only used internally, and must be unique for each game.

This can be saved as "user://launcher.ini" or "res://launcher.ini", with the first given preference.

## Game Config

Config file keys for title, executable, capsule, and background will override any values detected in the directory scan. 

Set 'visible = false' to quickly hide broken games without deleting them.

## Attributes

Officially supported attributes:
- multiplayer
- singleplayer
- coop
- pvp
- leaderboards
- trackball

## Arcade Fork

We forked this launcher to make a version for CGDA (Calgary Game Developers Association, https://www.calgary.games/). This is for a standup arcade cabinet, used for gamejam collections and showcasing locally made games. 

New features of this fork include:
- Screensaver
- Autoscroll
- INI Configs
- Popup Notices
- Mouse Support
- Overlay Image
- Tag-based Game Filtering
- Categories (TODO)

MrEliptik is the original creator of the game launcher:

https://github.com/MrEliptik/game_launcher

We've deviated too far to merge!

