-- =====================================================================================================================
-- DESCRIPTION:
--     Toggles the value of the "Colourize Folders" setting.  This setting dictates whether tracks should
--     be assigned a "manilla" colour when they are converted to folder tracks, as well as whether they
--     should be assigned the default colour for tracks when they are converted back to a regular track.
-- =====================================================================================================================
-- Load library functions and get this script's file name.
local SCRIPT_PATH      = ({reaper.get_action_context()})[2]
local SCRIPT_DIRECTORY = SCRIPT_PATH:match("^(.*[/\\])")
loadfile(SCRIPT_DIRECTORY .. "ReaFolders - .Library Functions.lua")()
local SCRIPT_NAME = GetFileNameFromPath(SCRIPT_PATH)
-- =====================================================================================================================

local CREATE_UNDO_BLOCK = true
BeginScript(SCRIPT_NAME, CREATE_UNDO_BLOCK)

-- Toggle the value of the "Colourize Folders" setting.
TogglePersistentBooleanSetting(SETTING_ColourizeFolders)

EndScript(SCRIPT_NAME, CREATE_UNDO_BLOCK)