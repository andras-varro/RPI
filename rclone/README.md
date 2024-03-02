# setup_rclone

Usually there is no ARM64 Linux (like Raspberry OS) client for the major cloud providers. There is, however, one software that bridges over this gap: rclone.

## Features:
* Download an install rclone
* Based on rclone config creates a services to connect to the remote and mount them

## Requires:
* which, curl: these are pre-installed with the standard Raspbian/Raspberry OS
* sudo rights

## How to use:
1. Make sure you have sudo rights
2. Make the script executable. Open a terminal window to the script location and execute:
```
chmod +x setup_rclone.sh
```
3. Execute the script ./setup_rclone.sh

## Configuration:
The script has not much configuration potential. Maybe in future versions.

## Troubleshooting
If something doesn't work out, read the output and please raise an issue.

## Disclaimer:
This software is distributed on an "AS IS" BASIS,  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
