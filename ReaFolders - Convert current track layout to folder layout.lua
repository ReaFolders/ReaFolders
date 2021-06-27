-- =====================================================================================================================
-- DESCRIPTION:
--     A folder track is defined as a track that has gone through the conversion process described by the
--     [Convert selected track(s) to folders] script.  This script iterates through all tracks in the Track
--     Control Panel, infers a folder layout from the states of the tracks, and then applies (as necessary)
--     new states to tracks such that the resulting layout represents the folder layout that was inferred.
--
--     Specifically, the logic employed by this script is as follows:
--         - If a track is found to have child tracks but it hasn't been converted to a folder track yet, then it gets
--           converted to a folder track.  See documentation of the [Convert selected track(s) to folders] script for
--           details on what this conversion entails.
--
--         - If a track is found to not have child tracks, but it is currently a folder track, then it is converted
--           back to a regular track.  See documentation of the [Convert selected folder(s) to regular tracks] script
--           for details on what this conversion entails.
--
--         - For each folder track that is found (including ones just converted to folders because they were found
--           to have child tracks), its "folder compact" mode is used to determine whether the track should currently
--           be expanded or collapsed.  If a folder track is not currently in the expanded/collapsed state that the
--           mode of its "folder compact" button suggests it should be in, then it is updated to visually be in that
--           state.  This will update the visibility of descendant tracks appropriately.
--
--           ----------------------------------
--           Details on "folder compact" modes:
--           ----------------------------------
--           The "folder compact" mode button on a track in the Track Control Panel can be used to put a track into
--           one of three modes:
--             - Normal:        A track is not a folder (as defined by REAPER) and has no children.
--
--             - Small:         A track is a folder (as defined by REAPER) and has at least one child.
--                              Each child track should be shrunk down to a smaller size.
--
--             - TinyChildren:  A track is a folder (as defined by REAPER) and has at least one child.
--                              Each child track should be shrunk down to a height of only a few pixels.
--
--           As the above states illustrate, the "folder compact" mode button on a track cycles through three states
--           when it is clicked (Normal --> Small --> TinyChildren).  When using this script, however, we want to
--           turn this button into an expand/collapse button.  So the way we do this is by "removing" the middle
--           "Small" mode.  That is, whenever we detect that the button has been pressed on a track, putting that
--           track into "Small" mode, we programatically jump the track forward and put it into "TinyChildren" mode.
--           The next click of the button will then result in the track going back into "Normal" mode.  With this
--           change in place, tracks now have only two modes that they cycle through (Normal and TinyChildren).
-- =====================================================================================================================
-- Load library functions and get this script's file name.
local SCRIPT_PATH      = ({reaper.get_action_context()})[2]
local SCRIPT_DIRECTORY = SCRIPT_PATH:match("^(.*[/\\])")
loadfile(SCRIPT_DIRECTORY .. "ReaFolders - .Library Functions.lua")()
local SCRIPT_NAME = GetFileNameFromPath(SCRIPT_PATH)
-- =====================================================================================================================

local CREATE_UNDO_BLOCK = true
BeginScript(SCRIPT_NAME, CREATE_UNDO_BLOCK)

-- Generate and apply a folder layout, based on the current state of all tracks in the current project.
GenerateFolderLayoutFromTrackLayout()

EndScript(SCRIPT_NAME, CREATE_UNDO_BLOCK)