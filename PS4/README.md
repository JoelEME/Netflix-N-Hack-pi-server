# Netflix N Hack for PS4

> [!NOTE]
> The PS4 version requires very specific circumstances to work. Workarounds are included below.

## Compatibility

Before proceeding, ensure the following:

1. **Netflix (with license) installed on your PS4 below the latest version**
    - If you have an existing jailbreak, simply install the vulnerable version for your region [EU](https://orbispatches.com/CUSA00127?v=01.53)  [US](https://orbispatches.com/CUSA00129?v=01.53) [JP](https://orbispatches.com/CUSA02988?v=01.53)
    - This is useful if you can’t get BD-JB or are stuck using PPPwn.
    - If you are on the latest firmware, you *can* downgrade Netflix via MITM by downloading from PSN.  
      You **cannot jailbreak**, but you will be prepared if a new kernel exploit releases.

2. **PS4 Firmware version must be between 8.00 and 12.02** (required for the Lapse exploit)


Need help? Ask me on [Discord](https://discord.gg/QMGHzzW89V)
---

## Downgrading Netflix

> [!NOTE]
> Please see the [Extended Storage Method](https://github.com/earthonion/Netflix-N-Hack/)

### Prerequisites
- Python
- mitmproxy
- Internet access

> [!Warning]
> Downgrading is experimental and may not work for you. If you accidentally update to 1.59 you cannot downgrade with MITM. **Extended storage images are planned**

> [!NOTE]
> If your previous Netflix version is above 1.53. You will need an existing Jailbreak to fix the "Please update the application" notification.
> FTP into /user/download/CUSA00XXX (whichever region you are in)
and delete "download0_info.dat"

### Install & Run Downgrade Proxy
```bash
# Install mitmproxy
pip install mitmproxy

# Start the downgrade proxy
mitmproxy -s downgrader.py --ssl-insecure --set stream_large_bodies=3m
```


**Console Instructions**

On your PS4:



go into settings -> network -> set up internet connection ->  wifi or lan -> Custom -> automatic -> do not specify -> DNS Automatic -> automatic -> Proxy server **USE** -> enter your computer ip address port : 8080

>[!TIP]
> To get you local IP address, in a console run the command
>Windows: Open CMD -> run `ipconfig` -> look under “IPv4 Address” in your active adapter (Wi-Fi/Ethernet).
>
>Linux: Run `ip a` → find your network interface (e.g., eth0, wlan0) → check the inet line.
>
>Mac: Run `ifconfig` → find en0/en1 → read the `inet` value (or `ipconfig getifaddr en0` for Wi-Fi).

1. Go to Netflix **on the home screen**


2. Press **Options** on your controller 


3. Select **Check for Updates**


---

## Exploit

### Public Server

Set your proxy in ps4 network settings to this:

> [!NOTE]
> **Address**: `172.105.156.37`
> **Port**: `42069`

Then simply open Netflix 


### Host Locally


### Start MITM Proxy

```bash
mitmproxy -s proxy.py
```

### Set your proxy in ps4 network settings to your local ip (machine running mitmproxy)

Then simply open Netflix on your PS4.
(Exploit initialization takes ~30 seconds.)

# Important Notes

> [!NOTE]
> If PS4 kernel panics, or lapse fails; restart the console and try again.
>
> if Netflix crashes, just restart Netflix

Once complete, the exploit will look for a payload in `/data/payload.bin` if it is not found it will look on the root of a plugged in USB drive for a file named `payload.bin` and will automatically copy it to `/data/payload.bin`.

after initial exploit, USB is no longer needed. 

if payload is not found on either the USB or `/data/payload.bin`, a binloader will spawn on port 9021 for you to send via netcat or equivalent


# Credits
- HelloYunho for all the advise on porting lapse, and latest fw downgrade method 
- c0w-ar for working primitives and ROP chain

---

If you run into issues, feel free to message me on Discord!
