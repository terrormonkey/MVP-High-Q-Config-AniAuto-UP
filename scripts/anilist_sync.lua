-- Anilist Sync Script for MPV by Kwaery v.1.0 23.01.2026 08:29:33
local utils = require 'mp.utils'
local msg = require 'mp.msg'

-- Configuration
local ANILIST_TOKEN = "COPY ANILISTTOKEN IN HERE"

-- Ensure the path uses valid Lua string escaping for backslashes
local TARGET_PATH = "COPY FILEPATH OF UR ANIME FOLDER IN HERE"

-- Helper to check if string starts with prefix
local function starts_with(str, start)
    return str:sub(1, #start) == start
end

-- Helper to execute curl commands
local function curl_request(query, variables)
    local payload = utils.format_json({
        query = query,
        variables = variables
    })

    local args = {
        "curl",
        "-X", "POST",
        "-H", "Content-Type: application/json",
        "-H", "Accept: application/json",
        "-H", "Authorization: Bearer " .. ANILIST_TOKEN,
        "-d", payload,
        "https://graphql.anilist.co"
    }

    local res = utils.subprocess({ args = args })
    
    if res.status ~= 0 then
        msg.error("Curl failed: " .. (res.error or "unknown error"))
        return nil
    end

    local response_body = res.stdout
    if not response_body or response_body == "" then
        msg.error("Empty response from Anilist")
        return nil
    end

    return utils.parse_json(response_body)
end


-- Debug helper
local debug_enabled = false
local function debug_log(str)
    msg.info("[Anilist Debug] " .. str)
    if debug_enabled then
        mp.osd_message("[Debug] " .. str, 3) 
    end
end

local function toggle_debug()
    debug_enabled = not debug_enabled
    if debug_enabled then
        mp.osd_message("Anilist Debug: ON", 3)
    else
        mp.osd_message("Anilist Debug: OFF", 3)
    end
end

-- Key binding to toggle debug (Ctrl+d)
mp.add_forced_key_binding("ctrl+d", "anilist-toggle-debug", toggle_debug)

-- Function to normalize path for comparison
local function normalize_path(path)
    if not path then return "" end
    -- Lowercase and use backslashes for consistent comparison on Windows
    return path:gsub("/", "\\"):lower()
end

-- Parsing logic
local function parse_file_info(path)
    debug_log("Raw path: " .. tostring(path))
    
    local normal_path = normalize_path(path)
    local normal_target = normalize_path(TARGET_PATH)

    debug_log("Normalized Path: " .. normal_path)
    debug_log("Target Path: " .. normal_target)

    if not starts_with(normal_path, normal_target) then
        debug_log("Path does not start with target directory")
        return nil, "Path not in target directory"
    end

    -- Remove the base path (case-insensitive match length)
    -- We use original path substring to preserve case for the folder name
    local relative_path_start_index = #TARGET_PATH + 2
    local relative_path = path:gsub("/", "\\"):sub(relative_path_start_index)
    
    debug_log("Relative Path: " .. relative_path)

    -- Extract Series Name (First folder in relative path)
    local series_name = relative_path:match("^(.-)\\")
    if not series_name then
        series_name = relative_path:match("^(.-)%.[^%.]+$")
    end

     -- Extract Episode Number from filename
     local filename = relative_path:match("[^\\]+$")
     debug_log("Filename: " .. tostring(filename))
     
     local episode = nil
 
     -- Parsing attempts
     episode = filename:match(" %- (%d+)")
     if not episode then episode = filename:match("E(%d+)") end
     if not episode then episode = filename:match("Episode (%d+)") end
     if not episode then episode = filename:match("%[(%d+)%]") end
     if not episode then episode = filename:match("^(%d+) ") end -- Starts with number "01 Title..."
     if not episode then episode = filename:match("^(%d+)%.[^%.]+$") end -- Just number "05.mkv"

     debug_log("Parsed Series: " .. tostring(series_name))
     debug_log("Parsed Episode: " .. tostring(episode))
 
     if series_name and episode then
         return series_name, tonumber(episode)
     end
 
     return nil, "Could not parse series or episode"
end

local function clean_series_name(name)
    if not name then return "" end
    local original = name
    
    -- Remove release group/info in brackets/parentheses, e.g. (EMBER), [1080p]
    name = name:gsub("%b()", "")
    name = name:gsub("%b[]", "")
    
    -- Remove " - S 1..." or " S1..." (Season info and everything after)
    -- We assume season info usually marks the end of the title and start of metadata
    name = name:gsub(" %- S ?%d+.*", "")
    name = name:gsub(" S%d+ .*", "") -- Space S1 Space
    
    -- Remove specific keywords
    name = name:gsub("FULL SEASON", "")
    name = name:gsub("Batch", "")
    
    -- Trim whitespace and trailing hyphens
    name = name:match("^%s*(.-)%s*$")
    name = name:gsub("%s*-%s*$", "")
    name = name:match("^%s*(.-)%s*$")

    debug_log("Cleaned Series Name: '" .. original .. "' -> '" .. name .. "'")
    return name
end

local function update_anilist(series_name_raw, episode_num)
    local series_name = clean_series_name(series_name_raw)
    debug_log("Starting sync for: " .. series_name .. " Ep " .. episode_num)

    -- Step 1: Find the Anime and check Status
    -- Step 1: Check for ID in folder name
    local anilist_id = series_name_raw:match("^(%d+)")
    local data_search = nil

    if anilist_id then
        debug_log("ID found in folder: " .. anilist_id .. " -> Syncing by ID")
        local query_id = [[
        query ($id: Int) {
            Media(id: $id, type: ANIME) {
                id
                episodes
                title {
                    romaji
                    english
                }
                mediaListEntry {
                    id
                    status
                    progress
                }
            }
        }
        ]]
        data_search = curl_request(query_id, { id = tonumber(anilist_id) })
    else
        debug_log("No ID found, searching by name...")
        -- Fallback to name search
        local query_search = [[
        query ($search: String) {
            Media(search: $search, type: ANIME) {
                id
                episodes
                title {
                    romaji
                    english
                }
                mediaListEntry {
                    id
                    status
                    progress
                }
            }
        }
        ]]
        data_search = curl_request(query_search, { search = series_name })
    end
    
    if not data_search then
        debug_log("API Request Failed: No data returned")
        return
    end

    if not data_search.data or not data_search.data.Media then
        debug_log("API: Anime not found")
        return
    end

    local media = data_search.data.Media
    local entry = media.mediaListEntry

    debug_log("API: Found Anime ID: " .. tostring(media.id))

    if not entry then
        debug_log("API: Anime not in your list.")
        return
    end
    
    debug_log("API: Entry Status: " .. tostring(entry.status))
    debug_log("API: Current Progress: " .. tostring(entry.progress))

    -- Allow updating if status is CURRENT (Watching) or PLANNING
    if entry.status ~= "CURRENT" and entry.status ~= "PLANNING" then
        debug_log("Skipping: Status is " .. tostring(entry.status) .. " (Not Watching or Planning)")
        return
    end

    if entry.progress >= episode_num then
        debug_log("Skipping: Processed already matches or exceeds local episode.")
        mp.osd_message("Episode Update allrdy happened!", 5)
        return
    end

    -- Determine new status: COMPLETED if this is the last episode, otherwise CURRENT
    local new_status = "CURRENT"
    if media.episodes and episode_num >= media.episodes then
        new_status = "COMPLETED"
        msg.info("Last episode detected (" .. episode_num .. "/" .. media.episodes .. ") -> Setting to COMPLETED")
    end

    -- Step 2: Update Progress AND Status
    local query_update = [[
    mutation ($id: Int, $progress: Int, $status: MediaListStatus) {
        SaveMediaListEntry(id: $id, progress: $progress, status: $status) {
            id
            progress
            status
        }
    }
    ]]

    local data_update = curl_request(query_update, { id = entry.id, progress = episode_num, status = new_status })

    if data_update and data_update.data and data_update.data.SaveMediaListEntry then
        local new_progress = data_update.data.SaveMediaListEntry.progress
        local log_message = string.format("Synced: %s - Ep %d", media.title.romaji, new_progress)
        
        mp.osd_message("Episode synced to Anilist! (⌐■_■)", 5)
        msg.info(log_message)
    else
        mp.osd_message("Anilist Update Failed", 5)
        debug_log("Mutation Failed or Invalid Response")
    end
end

local function on_file_end()
    local path = mp.get_property("path")
    if not path then return end

    local series, episode = parse_file_info(path)
    
    if series and episode then
        update_anilist(series, episode)
    else
        msg.verbose("Skipping Anilist sync: " .. (episode or "Parsing failed"))
    end
end

-- Trigger when EOF is reached (works even if keep-open is on)
mp.observe_property("eof-reached", "bool", function(name, val)
    if val then
        debug_log("EOF reached. Syncing...")
        on_file_end()
    end
end)

-- Manual Trigger function
local function manual_sync_trigger()
    msg.info("Manual sync triggered via hotkey")
    mp.osd_message("Forcing sync...", 2)
    on_file_end()
end

-- Key binding to manually trigger sync (Ctrl+a)
mp.add_forced_key_binding("ctrl+a", "anilist-sync-now", manual_sync_trigger)

msg.info("Anilist Sync Script Loaded. Press Ctrl+a to sync manually.")
mp.osd_message("Anilist Sync Script Loaded", 3)


-- --- NEW BROWSER FEATURE ---

local function open_page_in_browser()
    local path = mp.get_property("path")
    if not path then 
        mp.osd_message("No file playing", 3)
        return 
    end

    local series_name_raw, _ = parse_file_info(path)
    if not series_name_raw then
        mp.osd_message("Could not detect anime name", 3)
        return
    end

    -- 1. Try to find ID in folder name (Start with digits)
    local anilist_id = series_name_raw:match("^(%d+)")
    
    if anilist_id then
        local url = "https://anilist.co/anime/" .. anilist_id
        msg.info("ID found in folder: " .. anilist_id .. " -> Opening URL")
        mp.osd_message("Opening Anilist ID: " .. anilist_id, 3)
        
        mp.command_native({
            name = "subprocess",
            args = {"cmd", "/c", "start", "", url},
            detach = true
        })
        return
    end

    -- 2. Fallback: Search by name if no ID found
    local series_name = clean_series_name(series_name_raw)
    mp.osd_message("No ID found, searching for: " .. series_name, 5)
    debug_log("Browsing for: " .. series_name)

    local query_url = [[
    query ($search: String) {
        Media(search: $search, type: ANIME) {
            siteUrl
            title {
                romaji
            }
        }
    }
    ]]

    local data = curl_request(query_url, { search = series_name })

    if not data or not data.data or not data.data.Media then
        mp.osd_message("Anime not found on Anilist", 5)
        return
    end

    local url = data.data.Media.siteUrl
    if url then
        msg.info("Opening URL: " .. url)
        mp.osd_message("Opening Anilist: " .. data.data.Media.title.romaji, 3)
        
        -- Windows specific command to open URL
        mp.command_native({
            name = "subprocess",
            args = {"cmd", "/c", "start", "", url},
            detach = true
        })
    else
        mp.osd_message("No URL found", 5)
    end
end

-- Register the binding (input.conf triggers this name)
mp.add_key_binding("ctrl+b", "anilist-open-page", open_page_in_browser)
