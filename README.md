## DISCONTINUED
No longer developing this as Pandora has stopped providing support to Australia
:(

# Pianobarkeep

pianobarkeep is a bash script that interacts with [pianobar](https://github.com/PromyLOPh/pianobar) through command-line arguments. It's designed specifically for use as a background program that can be controlled with a few keybindings.

This is heavily inspired by [control-pianobar](http://github.com/Malabara/control-pianobar) by Malabara, but has been almost completely re-written by me as an exercise in shell scripting, and to suit my needs.

## Requirements

- `bash`
- `pianobar`

### Optional

- `notify-send` is the default method of relaying output, though this can be modified by changing the `notify` function in the script.
- `rofi` is the default choice for retrieving a choice from the user, but this can be changed through the `ask` function in the script.
