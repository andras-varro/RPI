# tweaks

Wayland and Wayfire on Raspberry OS comes with some wrinkles that needs to be ironed out.

## Features:

* Enables the cube screen saver after 2 minutes.
* Blanks the screen after 5 minutes.
* Sets the Alt+Tab behavior to behave as expected: switch back and forth in the most-recently-used order. Note, however, that the minimized windows are not reacheable with this 'fix'. For that you need use the Alt+Esc, which triggers the original Alt+Tab behavior. The better solutioin would be to see this addressed in Wayfire.

## Requires:

* Wayland/Wayfire (this is the default ui of Raspberry OS)
* sed, grep: these are pre-installed with the standard Raspbian

## How to use:

1. Make the script executable. Open a terminal window to the script location and execute:
```
chmod +x tweaks.sh
```
1. Execute the script ./tweaks.sh

## Configuration:

The script has a configuration section at the beginning.

## Troubleshooting

If something doesn't work out, read the output and please raise an issue.

## Disclaimer:
This software is distributed on an "AS IS" BASIS,  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
