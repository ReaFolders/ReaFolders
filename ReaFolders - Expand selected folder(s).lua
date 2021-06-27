-- =====================================================================================================================
-- DESCRIPTION:
--     Expands all folder tracks that are currently selected in the Track Control Panel.  A folder track is defined as a
--     track that has gone through the conversion process described by the [Convert selected track(s) to folders] script.
-- =====================================================================================================================
-- Load library functions and get this script's file name.
local SCRIPT_PATH      = ({reaper.get_action_context()})[2]
local SCRIPT_DIRECTORY = SCRIPT_PATH:match("^(.*[/\\])")
loadfile(SCRIPT_DIRECTORY .. "ReaFolders - .Library Functions.lua")()
local SCRIPT_NAME = GetFileNameFromPath(SCRIPT_PATH)
-- =====================================================================================================================

local CREATE_UNDO_BLOCK = true
BeginScript(SCRIPT_NAME, CREATE_UNDO_BLOCK)

-- Get the total number of tracks in the current project.  This excludes the Master track.
local projectTrackCount = reaper.CountTracks(0)
if (projectTrackCount == 0) then return end

-- Get the number of tracks that are currently selected in the current project.  This excludes the Master track.
local selectedTracks, selectedTrackNumbers = GetSelectedTracks()
if (#selectedTracks == 0) then return end

-- For each selected track:
for iSelectedTrack = 1, #selectedTracks do
    -- Get the selected track.
    local selectedTrack       = selectedTracks[iSelectedTrack]
    local selectedTrackNumber = selectedTrackNumbers[iSelectedTrack]
    DebugMsgL("Track " .. selectedTrackNumber .. " is selected.")

    -- If the selected track is a folder track, then put it into the "c"
    if (IsFolderTrack(selectedTrack)) then
        ExpandFolderTrack(selectedTrack, selectedTrackNumber, projectTrackCount)
    end
end

-- Refresh the Track Control Panel and Mixer Control Panel so the change is rendered.  Without
-- this, the change won't be drawn until the next time a click occurs inside the TCP or MCP.
-- Note that the "isMinor" parameter here works as follows:
--     true:  Only the TCP will be re-rendered
--     false: Both the TCP and the MCP will be re-rendered
reaper.TrackList_AdjustWindows(false)

EndScript(SCRIPT_NAME, CREATE_UNDO_BLOCK)