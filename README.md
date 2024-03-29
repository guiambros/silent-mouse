# Silent Mouse

Are you annoyed by frequent "low battery" notifications from your wireless mouse or keyboard on a Linux desktop using Gnome? Do you want to stop this madness?

This script will walk you through the steps to download, patch and recompile `upower`, and fix it once and for all. For more details and background, read this [blog post](https://wrgms.com/disable-mouse-battery-low-spam-notification/) for more details.


## What does it do?

The script detects the Linux distribution and attempts to download `upower` source code, injects a few lines of code to supress these battery alerts, and then compiles everything and puts the new binaries in the correct locations.

The original binaries are preserved, in cade you want to restore the system to its original state.


## Is it safe?

The script tries to be very conservative and will stop in case of any errors. It was tested with  common Ubuntu, Debian and Manjaro distributions (see below), and saves the original binaries in case you want to restore them later. Alternatively, you can reinstall `upower` with `apt install --reinstall upower` (Debian-based distros), or `pacman -S upower` (Manjaro).

Please note that THIS CODE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND. The author and contributors shall not be liable for any direct, indirect, incidental, or consequential damages arising from the use of this software. Users are solely responsible for any risks associated with using this software and by using it, indicate acceptance of these terms.


## Getting started

```
git clone https://github.com/guiambros/silent-mouse
cd silent-mouse
bash silent-mouse.sh
```

By default this disables only wireless mouse notifications. If you want to disable wireless keyboard notifications, you can add `--keyboard` to the script:

```
git clone https://github.com/guiambros/silent-mouse
cd silent-mouse
bash silent-mouse.sh --keyboard
```


## Distributions tested

This script was [tested](https://github.com/guiambros/silent-mouse/actions/runs/6986581475) with the following distributions / versions:

| Distribution | Versions tested                           |
| ------------ | ----------------------------------------- |
| Ubuntu       | 16.04, 18.04, 20.04, 22.04, 23.10         |
| Debian       | 10 (buster), 11 (bullseye), 12 (bookworm) |
| Manjaro      | manjaro 23.1                              |

If you're using another version, please [open an issue](https://github.com/guiambros/silent-mouse/issues) and I'll do my best to add support for it.

⚠️  Disclaimer: this is provided as is; you are responsible for checking the accuracy of the patch and ensure it won't ruin your system. Having said that, please open an issue if it doesn't work for you.
