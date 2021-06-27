-- =====================================================================================================================
-- DESCRIPTION:
--     Enables or disables a loop that keeps running in the background.  The loop does the following:
--         - Automatically converts tracks in the Track Control Panel to folder tracks when they have child tracks.
--         - Automatically converts folder tracks back to regular tracks when they no longer have child tracks.
--         - Automatically expands/collapses folder tracks based on the "folder compact" mode that is assigned to them.
--
--     A folder track is defined as a track that has gone through the conversion process described by the
--     [Convert selected track(s) to folders] script.
--
--     NOTE: When running this script multiple times, you will see REAPER's "script is already running in the
--           background" message.  Always select the "New instance" option.  The script itself tracks the current
--           on/off state.  If you use the "Terminate instances" option, then the script can get confused about
--           whether it's already running.  If that happens, invoking the script twice should correct things.
-- =====================================================================================================================
-- Load library functions and get this script's file name.
local SCRIPT_PATH      = ({reaper.get_action_context()})[2]
local SCRIPT_DIRECTORY = SCRIPT_PATH:match("^(.*[/\\])")
loadfile(SCRIPT_DIRECTORY .. "ReaFolders - .Library Functions.lua")()
local SCRIPT_NAME = GetFileNameFromPath(SCRIPT_PATH)
-- =====================================================================================================================

local CREATE_UNDO_BLOCK = false
local actionContext = BeginScript(SCRIPT_NAME, CREATE_UNDO_BLOCK)

-- Using REAPER's Get/SetExtState() functions, set up some functions that represent getters and setters
-- for a global "variable" that will be used to track whether the loop in this script is currently running.
-- This will be used to allow consecutive invocations of this script to toggle between starting and stopping
-- the looping function.  When starting and stopping the looping function, we'll also update the "State"
-- column in the Actions list for this script, so that it shows the current running state ("on" or "off").
function SetIsLoopRunning(isRunning)
    local scriptSectionID = actionContext[3]
    local scriptCommandID = actionContext[4]

    if (isRunning) then
        reaper.SetExtState(REAFOLDERS_SECTION_ID, "AutomaticFoldersOn", "true", false) -- Don't persist the setting when REAPER is closed
        reaper.SetToggleCommandState(scriptSectionID, scriptCommandID, 1)              -- Display "on" in the Actions list "State" column
    else
        reaper.SetExtState(REAFOLDERS_SECTION_ID, "AutomaticFoldersOn", "false", false) -- Don't persist the setting when REAPER is closed
        reaper.SetToggleCommandState(scriptSectionID, scriptCommandID, 0)               -- Display "off" in the Actions list "State" column
    end
end
function IsLoopRunning()
    return (reaper.GetExtState(REAFOLDERS_SECTION_ID, "AutomaticFoldersOn") == "true")
end


-- Set up the duration (in seconds) that needs to elapse between one invocation of the loop
-- in this script and a subsequent invocation before the loop will actually run its track
-- layout logic.  The looping function will use REAPER's defer() method to keep re-invoking
-- itself.  The defer() method has a timeout of about 33 milliseconds, so we also have to set
-- up a global variable that will be used by the looping function to record the time at which
-- it last ran its track layout logic.  This allows it to know when the timeout has occurred.
local TIMEOUT_SECONDS  =  1
local timeOfLastLayout =  0

-- Generate the looping function.  Once called, have it keep continuously re-invoking itself using REAPER's
-- defer() method.  Each time a timeout of [TIMEOUT_SECONDS] has occurred, have the function generate a folder
-- track layout from the current state of the Track Control Panel and then apply the generated layout to the TCP.
local function LoopingFunction()
    if (IsLoopRunning()) then
        local currentTime = os.time()
        if ((currentTime - timeOfLastLayout) >= TIMEOUT_SECONDS) then
            timeOfLastLayout = currentTime

            BeginScript(SCRIPT_NAME, CREATE_UNDO_BLOCK)
            GenerateFolderLayoutFromTrackLayout()
            EndScript(SCRIPT_NAME, CREATE_UNDO_BLOCK)
        end

        -- The defer() call will cause this function to keep re-invoking itself forever.  To stop it,
        -- either run this script a second time, or invoke REAPER's [Close all running ReaScripts] script.
        reaper.defer(LoopingFunction)
    end
end

-- Have each invocation of this script toggle between starting and stopping the looping
-- function.  Proceed based on whether the looping function is already running.
if (IsLoopRunning() == false) then
    -- The loop is not already running.  Start it now by performing the initial invocation of it.
    DebugMsgL("Loop is not running.  Starting it now.")
    SetIsLoopRunning(true)
    LoopingFunction()
else
    -- The loop is already running.  Update the variable that tracks running state
    -- and allow the function to stop itself after its next timeout occurs.
    DebugMsgL("Loop is already running.  Stopping it now.")
    SetIsLoopRunning(false)
end

EndScript(SCRIPT_NAME, CREATE_UNDO_BLOCK)