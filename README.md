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
8. In the optional **config.ini** you can override the above values and add more details.

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

## Arcade Fork

We forked this launcher to make a version for CGDA (Calgary Game Developers Association, https://www.calgary.games/). This is for a standup arcade cabinet, used for gamejam collections and showcasing locally made games.

## 💁‍♂️ About MrEliptik

MrEliptik is the original creator of the game launcher.

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
