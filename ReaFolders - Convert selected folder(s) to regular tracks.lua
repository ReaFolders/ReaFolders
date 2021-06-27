-- =====================================================================================================================
-- DESCRIPTION:
--     Iterates over each folder track in the Track Control Panel that is currently selected and converts it back
--     to a regular track.  See the description of the [Convert selected track(s) to folders] script to learn what
--     gets changed when a track is converted into a folder track.  To convert a track back to a regular track,
--     we:
--         - COLOUR  Reset the track's colour back to the default track colour for the current theme.
--
--         - ICON    Remove the track's icon.
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

    -- If the selected track is a folder track, convert it to a regular track.
    if (IsFolderTrack(selectedTrack)) then
        ConvertTrackToRegularTrack(selectedTrack, selectedTrackNumber)
        DebugMsgL("--------------------------------------------------------------------------------")
    end
end

EndScript(SCRIPT_NAME, CREATE_UNDO_BLOCK)