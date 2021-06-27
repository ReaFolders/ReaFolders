-- =====================================================================================================================
-- DESCRIPTION:
--     Expands all folder tracks found in the Track Control Panel.  A folder track is defined as a track that
--     has gone through the conversion process described by the [Convert selected track(s) to folders] script.
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

-- Expand each track that is a folder track.
for iTrack = 0, (projectTrackCount - 1) do
    local currentTrack       = reaper.GetTrack(0, iTrack)
    local currentTrackNumber = (iTrack + 1)
    if (IsFolderTrack(currentTrack)) then
        if (IsCollapsedFolderTrack(currentTrack)) then
            DebugMsgL("Folder track " .. currentTrackNumber .. " needs to be expanded.")
            ExpandFolderTrack(currentTrack, currentTrackNumber, projectTrackCount)
        else
            DebugMsgL("Folder track " .. currentTrackNumber .. " is already expanded.")
        end
        DebugMsgL("--------------------------------------------------------------------------------")
    end
end

-- Refresh the Track Control Panel and Mixer Control Panel so the change is rendered.  Without
-- this, the change won't be drawn until the next time a click occurs inside the TCP or MCP.
-- Note that the "isMinor" parameter here works as follows:
--     true:  Only the TCP will be re-rendered
--     false: Both the TCP and the MCP will be re-rendered
reaper.TrackList_AdjustWindows(false)

EndScript(SCRIPT_NAME, CREATE_UNDO_BLOCK)