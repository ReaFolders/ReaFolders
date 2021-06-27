-- =====================================================================================================================
--     ____             ______      __    __
--    / __ \___  ____ _/ ____/___  / /___/ /__  __________
--   / /_/ / _ \/ __ `/ /_  / __ \/ / __  / _ \/ ___/ ___/
--  / _, _/  __/ /_/ / __/ / /_/ / / /_/ /  __/ /  (__  )
-- /_/ |_|\___/\__,_/_/    \____/_/\__,_/\___/_/  /____/
--
-- "Because everyone needs a little manilla in their life."
--
-- =====================================================================================================================
-- THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
-- WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS
-- OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
-- OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--======================================================================================================================

-- #####################################################################################################################
-- DEBUGGING
-- #####################################################################################################################

-- For debugging.  Set based on whether debug messages should be enabled.
local DEBUG = false
function DebugMsg(message)  if (DEBUG) then reaper.ShowConsoleMsg(message)         end end
function DebugMsgL(message) if (DEBUG) then reaper.ShowConsoleMsg(message .. "\n") end end


-- #####################################################################################################################
-- VARIABLES
-- #####################################################################################################################

-- ========================================================
-- REAPER Variables
-- ========================================================
-- Variables for creating Undo records.
local UNDO_STATE_ALL        = -1   -- Every type of thing potentially changed
local UNDO_STATE_TRACKCFG   =  1   -- Track configuration settings changed (e.g. vol/pan/routing)
local UNDO_STATE_FX         =  2   -- Track FX changed
local UNDO_STATE_ITEMS      =  4   -- Track items changed
local UNDO_STATE_MISCCFG    =  8   -- Changes were made to loop selection, markers, regions, extensions, etc.
local UNDO_STATE_FREEZE     =  16  -- Track freeze changed
local UNDO_STATE_TRACKENV   =  32  -- Track's non-FX envelopes changed
local UNDO_STATE_FXENV      =  64  -- Track's FX envelopes changed (implied by UNDO_STATE_FX as well)
local UNDO_STATE_POOLEDENVS =  128 -- Changes were made to contents of automation items -- not position, length, rate etc of automation items, which is part of envelope state
local UNDO_STATE_FX_ARA     =  256 -- Changes were made to ARA state

-- "Folder Compact" modes for tracks.
local FOLDERCOMPACT_Normal       = 0
local FOLDERCOMPACT_Small        = 1
local FOLDERCOMPACT_TinyChildren = 2

-- ========================================================
-- Internal Settings
-- ========================================================
REAFOLDERS_SECTION_ID = "ReaFolders" -- Section ID used for all ReaFolders settings saved using SetExtState() (needs to be global)

-- Actions to perform on tracks that get hidden by a collapsed folder.
local HIDDEN_TRACK_ACTIONS_Unselect = true -- Whether hidden tracks should get unselected
local HIDDEN_TRACK_ACTIONS_Disarm   = true -- Whether hidden tracks should get disarmed

-- Folder colours.  By default, expanded and collapsed folders have the same "manilla" colour.
local COLOUR_FolderCollapsed = (0x1000000 | reaper.ColorToNative(249,224,128))
local COLOUR_FolderExpanded  = (0x1000000 | reaper.ColorToNative(249,224,128))

-- Icons used to represent folder tracks and their current expanded/collapsed state.
local ICON_NAME_FolderCollapsed = "folder.png"
local ICON_NAME_FolderExpanded  = "folder_down.png"

-- ========================================================
-- User Settings.
-- ========================================================
-- Setting names (these need to be global variables so they can be referenced by scripts).
SETTING_ColourizeFolders = "ColourizeFolders" -- Whether the colour of tracks converted to/from folders should be modified

-- Default values (every setting MUST declare a default value; see GetSetting()).
local SETTING_DEFAULT_ColourizeFolders = "true" -- By default we colourize folder tracks


-- #####################################################################################################################
-- FUNCTIONS
-- #####################################################################################################################

-- ========================================================
-- Helper Functions for Scripts
-- ========================================================

--[[To be called at the beginning of a script to execute common "startup" logic.  The "create undo block"
    parameter specifies whether or not an undo block should be created to record everything the script
    does before it calls EndScript().  This allows all performed actions to be undone/redone by the
    user.  The specified script name is what gets displayed as the action name in REAPER's Undo/Redo
    menu.  When a script calls BeginScript(), it MUST also make a call to EndScript() before exiting.
]]
function BeginScript(scriptName, createUndoBlock)
    -- Get the calling script's action context.
    local scriptActionContext = {reaper.get_action_context()}
    
    -- If debugging is enabled, output a header for the script.
    if (DEBUG) then
        local sectionID = scriptActionContext[3]
        local commandID = scriptActionContext[4]
        reaper.ClearConsole()
        reaper.ShowConsoleMsg("================================================================================\n")
        reaper.ShowConsoleMsg("[" .. sectionID .. "/" .. commandID .. "] " .. scriptName .. "\n")
        reaper.ShowConsoleMsg("================================================================================\n")
    end

    -- If we were told to do so, begin recording an Undo block.
    if (createUndoBlock) then
        reaper.Undo_BeginBlock()
    end
    
    -- To maximize performance, prevent REAPER's UI from updating until the script ends.
    reaper.PreventUIRefresh(1)
    
    -- Return the script's action context in case it needs it.
    return scriptActionContext
end

--[[To be called at the end of a script to execute common "shutdown" logic.  The parameter values
    specified MUST be identical to those that were used for the accompanying BeginScript() call.
]]
function EndScript(scriptName, createUndoBlock)
    -- If we were told to do so, end the Undo block that's currently recording.
    if (createUndoBlock) then
        reaper.Undo_EndBlock(scriptName, UNDO_STATE_TRACKCFG)
    end
    
    -- Allow REAPER's UI to update now that the script has finished.
    reaper.PreventUIRefresh(-1)
end

-- ========================================================
-- General Helper Functions
-- ========================================================

--[[Simplified way to get a Track's name.
]]
function GetTrackName(mediaTrack)
    local _, name = reaper.GetTrackName(mediaTrack)
    return name
end

--[[Simplified way to get a Track's number.
]]
function GetTrackNumber(mediaTrack)
    return math.tointeger(reaper.GetMediaTrackInfo_Value(mediaTrack, "IP_TRACKNUMBER"))
end

--[[Simplified way of checking whether a track is currently armed for recording.
]]
function IsTrackArmed(mediaTrack)
    return (reaper.GetMediaTrackInfo_Value(mediaTrack, "I_RECARM") == 1)
end

--[[Simplified way to get a Track's current "folder compact" mode.
]]
function GetTrackFolderCompactMode(mediaTrack)
    return reaper.GetMediaTrackInfo_Value(mediaTrack, "I_FOLDERCOMPACT")
end

--[[Simplified way to set a Track's "folder compact" mode.
]]
function SetTrackFolderCompactMode(mediaTrack, compactMode)
    if     (compactMode == FOLDERCOMPACT_Normal)       then DebugMsgL("Setting track folder compact mode to NORMAL.")
    elseif (compactMode == FOLDERCOMPACT_Small)        then DebugMsgL("Setting track folder compact mode to SMALL.")
    elseif (compactMode == FOLDERCOMPACT_TinyChildren) then DebugMsgL("Setting track folder compact mode to TINY CHILDREN.") end
    return reaper.SetMediaTrackInfo_Value(mediaTrack, "I_FOLDERCOMPACT", compactMode)
end

--[[Simplified way to set a Track's icon.
]]
function SetTrackIcon(mediaTrack, fileName)
    local retval, stringNeedBig = reaper.GetSetMediaTrackInfo_String(mediaTrack, "P_ICON", fileName, true)
end

--[[String "Ends with" helper.
]]
function StringEndsWith(string, endingToCheckFor)
    return ((endingToCheckFor == "") or (string:sub(-#endingToCheckFor) == endingToCheckFor))
end

--[[Returns the file name portion of a file that has the specified path.
]]
function GetFileNameFromPath(path)
    -- Get file name with extension.
    local start, finish = path:find('[%w%s!-=%[%]{-|]+[_%.].+')
    local fileNameWithExtension = path:sub(start,#path)

    -- Return file name without extension.
    return fileNameWithExtension:match("(.+)%..+")
end

--[[Returns a lowercase string representation of the specified boolean.
]]
function BoolToString(bool)
    if (bool) then return "true" else return "false" end
end

--[[Returns a boolean representation of the specified string, which must be either "1", "true", "True", "0", "false", or "False".
]]
function ParseBool(boolString)
    if     ((boolString == "1") or (boolString == "true")  or (boolString == "True"))  then return true
    elseif ((boolString == "0") or (boolString == "false") or (boolString == "False")) then return false end
    assert(false, "ParseBool: Specified 'boolString' parameter does not represent a boolean.")
end

-- ========================================================
-- Settings Helper Functions
-- ========================================================

--[[Sets a specified string as the value for a well-defined ReaFolders ExtState
    setting that has the specified name.  The "persist" parameter is a boolean
    that specifies whether the setting should persist when REAPER is closed.
]]
function SetSetting(settingName, valueString, persist)
    DebugMsgL("SetSetting(" .. settingName .. ").  Value=[" .. valueString .. "], Persist=" .. BoolToString(persist))
    reaper.SetExtState(REAFOLDERS_SECTION_ID, settingName, valueString, persist)
end

--[[Returns the current value for a specified well-defined ReaFolders ExtState setting.
]]
function GetSetting(settingName)
    DebugMsg("GetSetting(" .. settingName .. ").  ")

    -- Get the current value of the setting with the specified name.
    local currentSettingValue = reaper.GetExtState(REAFOLDERS_SECTION_ID, settingName)
    
    -- If the requested setting doesn't have a value yet, use its default value instead.
    if (currentSettingValue == "") then
        if (settingName == SETTING_ColourizeFolders) then
            currentSettingValue = SETTING_DEFAULT_ColourizeFolders
        end
        assert(currentSettingValue ~= nil, "GetSetting: A default value hasn't been declared for setting '" .. settingName .. "'.")
        DebugMsgL("Setting doesn't exist.  Returning default value: [" .. currentSettingValue .. "]")
    else
        DebugMsgL("Setting exists, current value is: [" .. currentSettingValue .. "]")
    end
    return currentSettingValue
end

--[[Simplifies reading of boolean settings.  Returns a boolean value representing the
    current value of a specified well-defined boolean ReaFolders ExtState setting.
]]
function GetBoolSetting(settingName)
    return ParseBool(GetSetting(settingName))
end

--[[Toggles a well-defined boolean ReaFolders ExtState setting.
]]
function TogglePersistentBooleanSetting(settingName)
    local currentBoolValue = ParseBool(GetSetting(settingName))
    SetSetting(settingName, BoolToString(not(currentBoolValue)), true)
end

-- ========================================================
-- Folder Helper Functions
-- ========================================================

--[[Checks whether a track is a descendant of a track that has a specified track number.
]]
function TrackHasTrackNumberAsAncestor(mediaTrack, trackNumber)
    local ancestorTrack = reaper.GetParentTrack(mediaTrack)
    while (ancestorTrack ~= nil) do
        local ancestorTrackNumber = math.tointeger(reaper.GetMediaTrackInfo_Value(ancestorTrack, "IP_TRACKNUMBER"))
        if (ancestorTrackNumber == trackNumber) then
            return true
        end
        ancestorTrack = reaper.GetParentTrack(ancestorTrack)
    end
    return false
end

--[[Checks whether a specified track belonging to the currently active project has at least one child track.
]]
function TrackHasChildren(mediaTrack)
    local trackNumber = GetTrackNumber(mediaTrack)
    local nextTrack   = reaper.GetTrack(0, trackNumber) -- GetTrack() is 0-based
    if (nextTrack ~= nil) then
        local parentOfNextTrack = reaper.GetParentTrack(nextTrack)
        if (parentOfNextTrack ~= nil) then
            return (GetTrackNumber(parentOfNextTrack) == trackNumber)
        end
    end
end

--[[Checks whether a specified track is a direct child of a track with a specified track number.
]]
function IsDirectChildTrack(parentTrackNumber, potentialChildTrack)
    local parentTrack = reaper.GetParentTrack(potentialChildTrack)
    if (parentTrack ~= nil) then
        return (GetTrackNumber(parentTrack) == parentTrackNumber)
    end
    return false
end

--[[Iterates through the tracks that follow the specified track and returns two
    equally sized lists.  The first list contains the tracks that were found to
    be descendants, and the second list contains the track numbers of those tracks.
]]
function GetTrackDescendants(projectTrackCount, trackNumber)
    DebugMsgL("    Finding descendants of track " .. trackNumber .. ".")
    local descendantTracks       = {}
    local descendantTrackNumbers = {}
    local iArrays                = 1

    -- Note: Track Numbers are 1-based, GetTrack() is 0-based.
    for iNextTrack = trackNumber, (projectTrackCount - 1) do
        local nextTrack       = reaper.GetTrack(0, iNextTrack)
        local nextTrackNumber = (iNextTrack + 1)

        -- Check if the track is a direct child.
        local isChild     = false
        local parentTrack = reaper.GetParentTrack(nextTrack)
        if (parentTrack ~= nil) then
            local parentTrackNumber = GetTrackNumber(parentTrack)
            isChild                 = (parentTrackNumber == trackNumber)
        end

        -- If the track isn't a direct child, iterate through its ancestors to see if it's a descendant.
        local isDescendant = false
        if ((parentTrack ~= nil) and (isChild == false)) then
            local ancestorTrack = reaper.GetParentTrack(parentTrack)
            while (ancestorTrack ~= nil) do
                local ancestorTrackNumber = GetTrackNumber(ancestorTrack)
                if (ancestorTrackNumber == trackNumber) then
                    isDescendant = true
                    break
                end
                ancestorTrack = reaper.GetParentTrack(ancestorTrack)
            end
        end

        -- If we determined that the track was a child/descendant, add it to our collection.
        if (isChild or isDescendant) then
            descendantTracks[iArrays]       = nextTrack
            descendantTrackNumbers[iArrays] = nextTrackNumber
            iArrays                         = (iArrays + 1)
        end
        if     (isChild)      then DebugMsgL("        Track " .. nextTrackNumber .. " is a child.")
        elseif (isDescendant) then DebugMsgL("        Track " .. nextTrackNumber .. " is a descendant.") end
    end

    return descendantTracks, descendantTrackNumbers
end

--[[Returns to the caller, two equally sized arrays.  The first array contains the tracks that are currently
    selected in the current project, and the second array contains the track numbers of those tracks.
]]
function GetSelectedTracks()
    local selectedTracks       = {}
    local selectedTrackNumbers = {}
    local iArrays              = 1

    DebugMsg("Selected tracks: [")
    local numSelectedTracks = reaper.CountSelectedTracks(0)
    for iSelectedTrack = 0, (numSelectedTracks - 1) do
        local selectedTrack       = reaper.GetSelectedTrack(0, iSelectedTrack)
        local selectedTrackNumber = GetTrackNumber(selectedTrack)
        selectedTracks[iArrays]       = selectedTrack
        selectedTrackNumbers[iArrays] = selectedTrackNumber
        iArrays = (iArrays + 1)

        if (DEBUG) then
            if (iSelectedTrack > 0) then reaper.ShowConsoleMsg(",") end
            reaper.ShowConsoleMsg("" .. selectedTrackNumber)
        end
    end
    DebugMsgL("]")

    return selectedTracks, selectedTrackNumbers
end

--[[Disarms each currently invisible track in a specified collection of tracks.  If the
    specified "selectedTracks" parameter is null, then this function will manually look
    up the collection of tracks that are currently selected in the current project.
]]
function UnselectAllInvisibleTracksInProject(selectedTracks, selectedTrackNumbers)
    DebugMsgL("Unselecting all tracks that are now invisible.")
    if (selectedTracks == nil) then
        selectedTracks, selectedTrackNumbers = GetSelectedTracks()
    end

    for iTrack = 1, #selectedTracks do
        if (reaper.IsTrackVisible(selectedTracks[iTrack], false) == false) then
            DebugMsgL("    Unselecting track " .. selectedTrackNumbers[iTrack] .. " since it's no longer visible.")
            reaper.SetTrackSelected(selectedTracks[iTrack], false)
        end
    end
end

-- ========================================================
-- Main Folder Functions Invoked by Scripts
-- ========================================================

--[[Modifies a specified folder track such that it represents a folder track that is in the specified visual state.
]]
function UpdateFolderTrackVisualState(folderTrack, isExpanded)
    if (isExpanded) then
        -- Put the specified folder track into the expanded state.
        DebugMsgL("Putting folder track into the EXPANDED visual state.")

        DebugMsgL("    Applied expanded icon.")
        SetTrackIcon(folderTrack, ICON_NAME_FolderExpanded)

        if (GetBoolSetting(SETTING_ColourizeFolders)) then
            DebugMsgL("    Applied expanded colour.")
            reaper.SetTrackColor(folderTrack, COLOUR_FolderExpanded)
        end

        SetTrackFolderCompactMode(folderTrack, FOLDERCOMPACT_Normal)
    else
        -- Put the specified folder track into the collapsed state.
        DebugMsgL("Putting folder track into the COLLAPSED visual state.")

        DebugMsgL("    Applied collapsed icon.")
        SetTrackIcon(folderTrack, ICON_NAME_FolderCollapsed)

        if (GetBoolSetting(SETTING_ColourizeFolders)) then
            DebugMsgL("    Applied collapsed colour.")
            reaper.SetTrackColor(folderTrack, COLOUR_FolderCollapsed)
        end

        SetTrackFolderCompactMode(folderTrack, FOLDERCOMPACT_TinyChildren)
    end
end

--[[Converts a specified track into an expanded folder track.
]]
function ConvertTrackToFolderTrack(mediaTrack, mediaTrackNumber)
    DebugMsgL("Converting track " .. mediaTrackNumber .. " to a folder track.")

    -- Put newly created folder tracks into the "expanded" state by default.
    local isExpanded = true
    UpdateFolderTrackVisualState(mediaTrack, isExpanded)
end

--[[Converts a specified folder track back into a regular track.
]]
function ConvertTrackToRegularTrack(folderTrack, folderTrackNumber)
    DebugMsgL("Converting track " .. folderTrackNumber .. " to a regular track.")

    -- Remove the track's icon.
    SetTrackIcon(folderTrack, "")
    DebugMsgL("    Removed track icon.")

    -- Set the track's colour back to the default track colour for the current theme.  For this
    -- operation we try to look the default track colour up dynamically using the "GetThemeColor()"
    -- API method, but this method only exists for REAPER v6.11+.  If this is an older version
    -- of REAPER, we make a best effort attempt and use the hardcoded value we think is right.
    if (GetBoolSetting(SETTING_ColourizeFolders)) then
        local defaultTrackColour = (0x1000000 | reaper.ColorToNative(129,137,137))
        if (reaper.APIExists("GetThemeColor")) then
            defaultTrackColour = reaper.GetThemeColor("col_seltrack2", 0)
        end
        reaper.SetTrackColor(folderTrack, defaultTrackColour)
        DebugMsgL("    Applied default track colour.")
    end
end

--[[Checks if a track is a folder track created by us.  Right now, the algorithm is based purely
    on icon.  If the track has the "Collapsed" icon, then it's a collapsed folder created by
    us.  If the track has the "Expanded" icon, then it's an expanded folder created by us.
]]
function IsFolderTrack(mediaTrack)
    local retval, iconFileName = reaper.GetSetMediaTrackInfo_String(mediaTrack, "P_ICON", "", false)
    return (StringEndsWith(iconFileName, ICON_NAME_FolderCollapsed) or StringEndsWith(iconFileName, ICON_NAME_FolderExpanded))
end

--[[Checks if a track is a currently collapsed folder track that was created by us.
]]
function IsCollapsedFolderTrack(mediaTrack)
    local retval, iconFileName = reaper.GetSetMediaTrackInfo_String(mediaTrack, "P_ICON", "", false)
    return StringEndsWith(iconFileName, ICON_NAME_FolderCollapsed)
end

--[[Hides or shows a descendant track of a folder track.  Meant to be called on tracks that are
    to be hidden or shown as the result of a folder track being put into a collapsed/expanded state.
]]
function ShowOrHideDescendantTrackOfFolder(descendantTrack, isVisible)
    -- Set the specified track's visibility in both the TCP and MCP to the specified value.
    local               isVisibleNumeric = 0
    if (isVisible) then isVisibleNumeric = 1 end
    reaper.SetMediaTrackInfo_Value(descendantTrack, "B_SHOWINTCP",   isVisibleNumeric)
    reaper.SetMediaTrackInfo_Value(descendantTrack, "B_SHOWINMIXER", isVisibleNumeric)

    -- Perform any additional "hidden track actions" that are necessary.

    -- If hidden tracks need to be unselected, then unselect the specified track if it's selected.
    if (HIDDEN_TRACK_ACTIONS_Unselect and reaper.IsTrackSelected(descendantTrack)) then
        DebugMsgL("        Unselecting the track since it's no longer visible.")
        reaper.SetTrackSelected(descendantTrack, false)
    end

    -- If hidden tracks need to be disarmed, then unselect the specified track if its armed.
    if (HIDDEN_TRACK_ACTIONS_Disarm and IsTrackArmed(descendantTrack)) then
        DebugMsgL("        Disarmming the track since it's no longer visible.")
        reaper.SetMediaTrackInfo_Value(descendantTrack, "I_RECARM", 0)
    end
end

--[["Closes" a specified folder track by putting it into a "collapsed" state and hiding its descendants.
]]
function CollapseFolderTrack(folderTrack, folderTrackNumber, projectTrackCount)
    DebugMsgL("Collapsing track " .. folderTrackNumber .. ".")

    -- Hide each descendant track of the specified folder track (hide each track "inside" the folder).
    local descendantTracks, descendantTrackNumbers = GetTrackDescendants(projectTrackCount, folderTrackNumber)
    for iDescendant = 1, #descendantTracks do
        local descendantTrack       = descendantTracks[iDescendant]
        local descendantTrackNumber = descendantTrackNumbers[iDescendant]
        DebugMsgL("    Hiding track " .. descendantTrackNumber .. ".")
        ShowOrHideDescendantTrackOfFolder(descendantTrack, false)
    end

    -- Give the specified folder track the "collapsed" visual state.
    UpdateFolderTrackVisualState(folderTrack, false)
end

--[["Opens" a specified folder track by putting it into an "expanded" state, and showing
    its descendants (excluding those that should remain hidden due to nested folders).
]]
function ExpandFolderTrack(folderTrack, folderTrackNumber, projectTrackCount)
    DebugMsgL("Expanding track " .. folderTrackNumber .. ".")

    -- If the specified folder track is currently visible, make its applicable descendant tracks visible as well.
    if (reaper.IsTrackVisible(folderTrack, false)) then
        -- Get the folder track's descendant tracks (the tracks "inside" the folder).
        local descendantTracks, descendantTrackNumbers = GetTrackDescendants(projectTrackCount, folderTrackNumber)

        -- For each descendant:
        for iDescendant = 1, #descendantTracks do
            local descendantTrack       = descendantTracks[iDescendant]
            local descendantTrackNumber = descendantTrackNumbers[iDescendant]

            -- Determine whether expansion of the folder track should cause the descendant
            -- to become visible.  Proceed based on whether the descendant is a direct
            -- child, or some other descendant (meaning that nested tracks are at play).
            local makeDescendantVisible = false
            if (IsDirectChildTrack(folderTrackNumber, descendantTrack)) then
                -- The descendant is a direct child.  In this case it should become visible.
                makeDescendantVisible = true
            else
                -- The descendant is not a direct child, so it's a nested track.  In this case,
                -- we need to iterate up its ancestor track chain, checking to see if it's located
                -- under any other folder track that is currently collapsed.  If so, then the
                -- descendant should remain hidden.  Othwerwise, it should become visible.
                makeDescendantVisible = true
                local ancestorTrack = reaper.GetParentTrack(descendantTrack)
                while (ancestorTrack ~= folderTrack) do
                    if (IsCollapsedFolderTrack(ancestorTrack)) then
                        makeDescendantVisible = false
                        break
                    end
                    ancestorTrack = reaper.GetParentTrack(ancestorTrack)
                end
            end

            -- If we determined that the descendant should become visible, make it visible.
            if (makeDescendantVisible) then
                DebugMsgL("    Making track " .. descendantTrackNumber .. " visible.")
                ShowOrHideDescendantTrackOfFolder(descendantTrack, true)
            else
                DebugMsgL("    Keeping track " .. descendantTrackNumber .. " hidden.")
            end
        end
    end

    -- Give the specified folder track the "expanded" visual state.
    UpdateFolderTrackVisualState(folderTrack, true)
end

--[[Meant to be called inside a loop that keeps running for the duration of a REAPER session.  Iterates
    through all tracks in the Track Control Panel of the currently active Project, infers a folder
    layout from the current properties/states of those tracks, and then applies new property values/
    states to tracks, such that the final track layout reflects the folder layout that was inferred.
]]
function GenerateFolderLayoutFromTrackLayout()
    -- Get the total number of tracks in the current project.  This excludes the Master track.
    -- If the current project has no tracks, return immediately since we have no work to do.
    local projectTrackCount = reaper.CountTracks(0)
    if (projectTrackCount == 0) then return end

    -- For each track:
    for iTrack = 0, (projectTrackCount - 1) do
        -- Get the currnent track.
        local currentTrack       = reaper.GetTrack(0, iTrack)
        local currentTrackNumber = (iTrack + 1)
        DebugMsg("Track " .. currentTrackNumber .. ".  ")

        -- Get the current track's "folder compact" mode.
        local compactMode = GetTrackFolderCompactMode(currentTrack)
        local isNormal       = (compactMode == FOLDERCOMPACT_Normal)
        local isSmall        = (compactMode == FOLDERCOMPACT_Small)
        local isTinyChildren = (compactMode == FOLDERCOMPACT_TinyChildren)
        if (DEBUG) then
            if     (isNormal)       then DebugMsg("Compact=Normal.  ")
            elseif (isSmall)        then DebugMsg("Compact=Small.  ")
            elseif (isTinyChildren) then DebugMsg("Compact=Tiny.  ") end
        end

        -- Proceed based on whether the current track has children.
        local hasChildren = TrackHasChildren(currentTrack)
        if (hasChildren) then
            DebugMsgL("Has children.")
            -- The current track has children.  If the track isn't already a folder track, turn it into one now.
            if (IsFolderTrack(currentTrack) == false) then
                DebugMsgL("Is regular track.  Converting to FOLDER track.")
                ConvertTrackToFolderTrack(currentTrack, currentTrackNumber)
            end

            -- If the current track (which is (now) a folder track) has a "folder compact"
            -- mode of "Small" or "Tiny Children", then make sure it's collapsed.  Otherwise,
            -- if it has a mode of "Normal", then make sure the folder track is expanded.
            local compactMode = GetTrackFolderCompactMode(currentTrack)
            local isNormal       = (compactMode == FOLDERCOMPACT_Normal)
            local isSmall        = (compactMode == FOLDERCOMPACT_Small)
            local isTinyChildren = (compactMode == FOLDERCOMPACT_TinyChildren)
            if (isSmall or isTinyChildren) then
                -- The folder track is in "Small" or "Tiny Children" mode.  Collapse the folder (if not already collapsed).
                if (IsCollapsedFolderTrack(currentTrack) == false) then
                    DebugMsgL("Track should be collapsed but isn't.")
                    CollapseFolderTrack(currentTrack, currentTrackNumber, projectTrackCount)
                end

                -- If the folder track is in "Small" mode, upate it to "Tiny Children" mode so that
                -- the next click of the "folder compact" mode button will put the folder track back
                -- into "Normal" mode, effectively turning the button into an "expand" button.
                if (isSmall) then
                    DebugMsgL("Changing compact mode to TINY.")
                    SetTrackFolderCompactMode(currentTrack, FOLDERCOMPACT_TinyChildren)
                end
            elseif (isNormal) then
                -- The folder track is in "Normal" mode.  Expand the folder (if it isn't already expanded).
                if (IsCollapsedFolderTrack(currentTrack)) then
                    DebugMsgL("Track should be expanded but isn't.")
                    ExpandFolderTrack(currentTrack, currentTrackNumber, projectTrackCount)
                end
            end
        else
            -- The current track has no children.  If it's currently a folder
            --  track, then we need to convert it back to a regular track.
            DebugMsgL("No children.")
            if (IsFolderTrack(currentTrack)) then
                DebugMsgL("Is folder track.  Converting to REGULAR track.")
                ConvertTrackToRegularTrack(currentTrack, currentTrackNumber)
            end

            -- Ensure the current track's "folder compact" mode is now set back to "normal".
            if (isNormal == false) then
                SetTrackFolderCompactMode(currentTrack, FOLDERCOMPACT_Normal)
            end
        end
        DebugMsgL("--------------------------------------------------------------------------------")
    end
end