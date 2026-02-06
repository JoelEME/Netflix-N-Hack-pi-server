# Netflix 'N Hack for only proxy local on raspberry pi



Inject custom JavaScript into the Netflix PS5 error screen by intercepting Netflix's requests to localhost.

PS5 firmware version: 4.03-12.XX

Lowest working version: https://prosperopatches.com/PPSA01614?v=05.000.000 (Needs to be properly merged) 

**Recommended download link merged 6.00:** https://pkg-zone.com/details/PPSA01615

> This project uses a local MITM proxy to inject and execute `inject.js` on the Netflix error page

> [!IMPORTANT]
> Jailbreaking or modifying your console falls outside the manufacturer’s intended use.  
Any execution of unsigned or custom code is performed **solely at your own risk**.
>
> By using this project, you acknowledge that:
>
> - You assume full responsibility for any damage, data loss, or system instability.  
> - The contributors and maintainers of this repository **cannot be held liable** for any issues arising from the use of this code or any related instructions.  
> - This project is provided **“as is”**, without warranty of any kind, express or implied.
>
> Proceed only if you understand and accept these risks.

Having issues? Let me know on [Discord](https://discord.gg/QMGHzzW89V)
---
# Instructions

raspberry pi
Installing is as simple as running this one command in a terminal

wget -qO- https://raw.githubusercontent.com/JoelEME/Netflix-N-Hack-pi-server/refs/heads/main/install_netflix_n_hack.sh | bash

---
# How to run proxy locally

## Installation & Usage



```

### Network / Proxy Setup

On your PS5:

1. Go to Settings > Network > Settings > Set Up Internet Connection.  

2. Scroll to the bottom and select Set Up Manually.  

3. Choose Connection Type **Use Wi-Fi** or **Use a LAN Cable**
If using **Wi-Fi**:
Choose **Enter Manually**, Enter your SSID **Wi-Fi network name**. Set **Security Method** to **WPA-Personal/WPA2..** (or similar) then Enter your ***Wi-Fi network password**.

4. Use Automatic for DNS Settings and MTU Settings.

5. At Proxy Server, choose Use and enter:

- IP address: \<your local machine IP\>

- Port: 8080

6. Press Done and wait for the connection to establish
- You may see **Can't connect to the internet** — this is expected and can be ignored after pressing OK.

7. Edit inject.js and inject_elfldr_automated.js:

```
const ip_script = "10.0.0.2"; // IP address of computer running mitmproxy.
const ip_script_port = 8080; //port which mitmproxy is running on

```

> Make sure your PC running mitmproxy is on the same network and reachable at the IP you entered.

### Open Netflix and wait. 


> [!NOTE]
If you see elfldr listening on port 9021 you can send your elf payload. 

### if it fails reboot and try again

### Troubleshooting
- If the Netflix application crashes shortly after opening it, reopen it to retry. 
- If you see a green text error "Exception" press X or O to retry. 
- If Lapse fails you will see a notification telling you to reboot the console, you must reboot to retry.



---

### Credits
- [c0w-ar](https://github.com/c0w-ar/) for complete inject.js userland exploit and lapse port from Y2JB!
- [ufm42](https://github.com/ufm42) for regex sandbox escape exploit and ideas!
- [autechre](https://github.com/autechre-warp) for the idea!
- [Dr.Yenyen](https://github.com/DrYenyen) for testing and coordinating system back up, M.2 Drives, Extended Storage, making PS5 Extended storage Image and much more help!
- [Gezine](https://github.com/gezine) for help with exploit/Y2JB for reference and original lapse.js!
- Rush for creating system backup, 256GB and 2TB M.2 Images, PS4 Extended Storage Images and hours of testing!!
- [Jester](https://github.com/god-jester) for testing 2TB and devising easiest imaging method, and gathering all images for m.2!
- [TeRex777](https://x.com/TeRex777_) for PS5 App Extended Storage method. 
