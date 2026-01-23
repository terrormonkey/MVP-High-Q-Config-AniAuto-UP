# 🎬 Anilist MPV Sync - Setup Guide by Kwaery // Terrormonkey 23.01.2026 08:50:25

This script automatically updates your Anilist watch progress when you finish an episode in MPV.

---

## 📁 Step 1: Install MPV

### Windows
1. Go to: https://sourceforge.net/projects/mpv-player-windows/files/64bit/ or https://mpv.io/installation/
2. Download the **latest .7z file** (example: `mpv-x86_64-20240101-git-abc1234.7z`)
3. Extract the folder anywhere you like (e.g., `C:\Program Files\mpv\`)
4. Run `mpv.exe` to test it works

> **Note:** MPV is portable - no installer needed. Just extract and run!

### Mac / Linux
- **Mac**: Install via Homebrew: `brew install mpv`
- **Linux**: Install via your package manager: `sudo apt install mpv` (Ubuntu/Debian)

---

## 📂 Step 2: Copy the Script

1. Find your MPV config folder:
   - **Windows**: `C:\Users\YOUR_USERNAME\AppData\Roaming\mpv\`
   - **Mac**: `~/.config/mpv/`
   - **Linux**: `~/.config/mpv/`

2. If the folder doesn't exist, create it.

3. Inside the `mpv` folder, create a folder called `scripts` (if it doesn't exist).

4. Copy `anilist_sync.lua` into the `scripts` folder.

---

## 🔑 Step 3: Get Your Anilist Token

1. Go to: https://anilist.co/api/v2/oauth/authorize?client_id=20740&response_type=token
2. Log in to your Anilist account (if not already logged in).
3. Click **"Authorize"**.
4. You will be redirected to a page. **Look at the URL in your browser's address bar**.
5. The URL will look like this:
   ```
   https://anilist.co/api/v2/oauth/pin#access_token=YOUR_LONG_TOKEN_HERE&token_type=Bearer&expires_in=31536000
   ```
6. Copy **only** the part after `access_token=` and before `&token_type`in the url.
   - This is your personal token. It's very long!

---

## ✏️ Step 4: Configure the Script

1. Open `anilist_sync.lua` with a text editor (Notepad, VS Code, etc.).

2. Find this line near the top (around line 6):
   ```
   local ANILIST_TOKEN = "eyJ0eXAi..."
   ```

3. Replace everything between the quotes `"..."` with **your token** from Step 3.

4. Find this line (around line 9):
   ```
   local TARGET_PATH = "I:\\Example's Anime Archiv"
   ```

5. Replace the path with **your anime folder path**.
   - Use **double backslashes** `\\` on Windows!
   - Example: `"D:\\Anime"` or `"C:\\Users\\YourName\\Videos\\Anime"`

6. **Save the file**.

---

## 📁 Step 5: Name Your Folders Correctly

For the script to find the right anime, name your folders like this:

```
ANILIST_ID - Anime Name
```

**Example:**
```
21 - ONE-PIECE
16498 - Attack on Titan
```

**How to find the Anilist ID:**
1. Go to the anime on anilist.co
2. Look at the URL: `https://anilist.co/anime/21/ONE-PIECE/`
3. The number after `/anime/` is the ID (in this case: `21`)

---

## ▶️ Step 6: Test It!

** IMPORTANT !!!: make sure the episode names are named like this for example: **
** "1.mkv" <- if it's episode 1 of that season "2.mkv" <- if it's episode 2 of that season "3.mkv" etc..**


1. Open an episode with MPV.
2. Watch until the end (or press **Ctrl+A** to manually sync).
3. Check your Anilist profile - the episode should be updated!

---

## ⌨️ Hotkeys

| Hotkey | Action |
|--------|--------|
| **Ctrl+A** | Manually trigger episode sync |
| **Ctrl+B** | Open anime's Anilist page in browser |
| **Ctrl+D** | Toggle debug messages on/off |

---

## ❓ Troubleshooting

**"Anime not found"**
- Make sure your folder name starts with the correct Anilist ID.

**"Not on your list"**
- Add the anime to your Anilist list first (Planning or Watching).

**Nothing happens**
- Press **Ctrl+D** to turn on debug mode and see what's happening.

---

## ✅ Done!

Enjoy automatic episode tracking! 🎉
