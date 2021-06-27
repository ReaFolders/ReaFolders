-- =====================================================================================================================
-- DESCRIPTION:
--     Iterates over each selected track in the Track Control Panel and converts it to a folder track.  A folder
--     track is defined as a track whose:
--         - COLOUR               Gets changed to a colour that visually represents a folder (i.e. manilla).
--
--         - FOLDER COMPACT MODE  Gets set to a value that visually represents a folder in an expanded or collapsed state.
--
--         - ICON                 Gets set to an icon that visually represents a folder in an expanded or collapsed state.
--
--         - VISIBILITY           In both the TCP and MCP gets binded to whether the track has a visible ancestor track
--                                that has also been previously converted to a folder track.
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

    -- Convert the selected track into a folder track.
    ConvertTrackToFolderTrack(selectedTrack, selectedTrackNumber)
    DebugMsgL("--------------------------------------------------------------------------------")
end

EndScript(SCRIPT_NAME, CREATE_UNDO_BLOCK)