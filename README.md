# Arcade Game Launcher

A simple game launcher meant as a frontend for an arcade cabinet. Especially useful for showcasing a bunch of games from game jams. 

Based on Godot Game Launcher from MrEliptik:
https://github.com/MrEliptik/game_launcher

*⚠ It's not aimed as being shipped with your game on Steam or other platforms.*

<p align="center">
  <img src="media/launcher_v0.0.1.gif">
</p>

## How to add games

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

`alt+enter` to toggle fullscreen

## Limitations

Right now, the launcher supports windows and linux. Mac shouldn't be complicated, we just need to detect the correct extensions or file types. 

All games or shortcuts must be placed inside the project subdirectory.

## Development

For development, you can use the **games** folder present in the project using the same configuration as explained above.

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

Example of a game config INI file. Using a config file for each game is optional, but must be called "config.ini" and placed alongside the game executable. 

```
[GAME]
title = "Game Title"
executable = "Game Executable.exe"
capsule = "Game Capsule.png"
background = "Game Background.png"
description = "Here is a text blurb.\n Remove this line to use description.txt."
category = ["Tools", "Tests"]
notice = "Coming Soon"
arguments = "--fullscreen --keyboard"

[SETTINGS]
order = 4
visible = true
available = true
pinned = false

[ATTRIBUTES]
singleplayer = false
multiplayer = true
coop = true
pvp = true
```

Config file keys for title, executable, capsule, and background will override any values detected in the directory scan. 

Set 'visible = false' to quickly hide broken games without deleting them.

All keys are optional. See source code to explain each key. Some keys may not yet be implemented, or shown as future possibilities.

## Arcade Fork

We forked this launcher to make a version for CGDA (Calgary Game Developers Association, https://www.calgary.games/). This is for a standup arcade cabinet, used for gamejam collections and showcasing locally made games. 

New features of this fork include:
- Screensaver
- Autoscroll
- INI Configs
- Popup Notices
- Mouse Support
- Overlay Image
- Categories (TODO)

Depending on MrEliptik's decisions, these features may or may not be moved to the main launcher repo. If you don't need the added complexity of these new features and just want to demo your games, you can be confident in using the original repo!

## 💁‍♂️ About MrEliptik

MrEliptik is the original creator of the game launcher:

Full time indie gamedev. You can find me everywhere 👇

- [Discord](https://discord.gg/83nFRPTP6t)
- [YouTube - Gamedev](https://www.youtube.com/@MrEliptik)
- [YouTube - Godot related](https://www.youtube.com/@mrelipteach)
- [Twitter](https://twitter.com/mreliptik) 
- [Instagram](https://www.instagram.com/mreliptik)
- [Itch.io](https://mreliptik.itch.io/)
- [All links](https://bento.me/mreliptik)

If you enjoyed this project and want to support me:

**Get exlusive content and access to my game's source code**

<a href='https://patreon.com/MrEliptik' target='_blank'><img height='36' style='border:0px;height:36px;' src='media/become_patreon.png' border='0' alt='Patreon link' /></a>

**One time donations**

<a href='https://ko-fi.com/H2H23ODS7' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://cdn.ko-fi.com/cdn/kofi1.png?v=3' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>
