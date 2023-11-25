# Silent Mouse

Are you annoyed by frequent "low battery" notifications from your wireless mouse or keyboard on a Linux desktop using Gnome? Do you want to stop this madness?

This script will walk you through the steps to download, patch and recompile `upower`, and fix it once and for all. For more details and background, read this [blog post](https://wrgms.com/disable-mouse-battery-low-spam-notification/) for more details.

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


## Versions tested

This script was tested with the following distributions and versions:

| Distribution | Versions tested                           |
| ------------ | ----------------------------------------- |
| Ubuntu       | 16.04, 18.04, 20.04, 22.04, 23.10         |
| Debian       | 10 (buster), 11 (bullseye), 12 (bookworm) |
| Manjaro      | manjaro 23.1                              |

Please open an [issue](https://github.com/guiambros/silent-mouse/issues) if you're using another version and run into problems.

⚠️  Disclaimer: this is provided as is; you are responsible for checking the accuracy of the patch and ensure it won't ruin your system. Having said that, please open an issue if it doesn't work for you.
