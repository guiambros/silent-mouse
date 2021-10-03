# Silent Mouse

Are you annoyed by frequent "low battery" notifications from your wireless mouse or keyboard on a Linux desktop using Gnome? Do you want to stop this madness?

This script will walk you through the steps to fix it. For more details and background, read this [blog post](https://wrgms.com/disable-mouse-battery-low-spam-notification/).

## Getting started

```
git clone https://github.com/guiambros/silent-mouse
cd silent-mouse
bash silent-mouse.sh
```

By default this disables only wireless mouse notifications. If you want to disable wireless keyboard notifications, you can add `--keyboard` to the script, i.e., 

```
git clone https://github.com/guiambros/silent-mouse
cd silent-mouse
bash silent-mouse.sh --keyboard
```


## Versions tested

This script was tested with the following distributions and versions:

| Distribution | Versions tested                                 |
| ------------ | ----------------------------------------------- |
| Ubuntu       | 18.04, 18.10, 19.04, 19.10, 20.04, 20.10, 21.04 |
| Debian       | 10 (buster), 11 (bullseye)                      |
| Manjaro      | manjaro 21                                      |


⚠️  Disclaimer: this is provided as is; you are responsible for checking the accuracy of the patch and ensure it won't ruin your system. Having said that, please open an issue if it doesn't work for you.
