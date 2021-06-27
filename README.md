```
=======================================================================================================================
    ____             ______      __    __
   / __ \___  ____ _/ ____/___  / /___/ /__  __________
  / /_/ / _ \/ __ `/ /_  / __ \/ / __  / _ \/ ___/ ___/
 / _, _/  __/ /_/ / __/ / /_/ / / /_/ /  __/ /  (__  )
/_/ |_|\___/\__,_/_/    \____/_/\__,_/\___/_/  /____/

"Because everyone needs a little manilla in their life."

=======================================================================================================================
Author: ReclaimerNo
=======================================================================================================================
THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS
OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
=======================================================================================================================

DESCRIPTION:
    At the time of this writing, REAPER does not have "folder functionality" built into it by default.  Here, we
    define "folder functionality" as the culmination of:
        - The ability to parent any non-Master audio track to another non-Master audio track.
        - The ability to classify a parent track as a "folder".
        - The ability to use a UI element (e.g. button) on a "folder" track in the Track Control Panel to expand
          or collapse the track.
        - Have "folder" tracks that have been collapsed automatically update all descendant tracks to be invisible,
          and have "folder" tracks that have been expanded automatically update all descendant tracks to be visible
          (except for those which are descendants of some other nested "folder" track that is also a descendant).

    ReaFolders (i.e. this library and the collection of scripts that accompany it and make use of it) has been
    created to implement the above described "folder" functionality.  Because the functionality had to be implemented
    by a third party, use comes at a cost.  If you can live with that cost, then ReaFolders is for you.

    Here we define that cost.  If you decide to use ReaFolders, then:

        1) The following icons (which come pre-installed by REAPER) become reserved and can ONLY
           be used by ReaFolders.  They are used to identify tracks as being ones that are currently
           considered to be "folders".  The icon used represents either an expanded or collapsed state.
               - [folder.png]
               - [folder_down.png]

        2) The "folder compact" mode for tracks becomes reserved for use by ReaFolders.  The "Normal"
           mode is used to represent a track that is expanded, and the "Small" and "TinyChildren"
           modes are used to represent a track that is collapsed.  When the [Convert current track
           layout to folder layout] and/or [Turn Automatic Folders on or off] scripts are used, any
           folder that has been assigned the "Small" mode will be reassigned the "TinyChildren" mode.
           This is done to convert the "folder compact" mode button into an expand/collapse button.

        3) The visibility property of tracks that have been converted to folders becomes reserved
           for use ONLY by ReaFolders.  Folder tracks that are considered to be hidden by a collapsed
           ancestor folder track will be made invisible.  And folder tracks that are considered
           to be shown due to all ancestor folder tracks being expanded are made visible.

        4) When a folder track gets collapsed, all descendants:
               - Get unselected
               - Get unarmed
           These actions aren't strictly necessary, but they are performed to prevent invisible tracks from
           unknowingly being acted upon.  To disable these actions, modify the [HIDDEN_TRACK_ACTIONS_*] variables.

        5) The colour property of tracks that are converted to folders becomes reserved and can only
           be set by ReaFolders.  Tracks that get converted to folders get assigned a "manilla" colour.
           This cost isn't strictly necessary, but is enabled by default to provide visual cues.  It
           can be turned on and off using the [Turn folder colourization on or off] Setting script.

USAGE:
    - For MANUAL control over folder layout, use this script whenever you want the layout to be visually refreshed:
          -----------------------------------------------
          [Convert current track layout to folder layout]
          -----------------------------------------------
          Converts tracks with children to folders, and converts tracks without children back to regular tracks.
          Updates the expanded/collapsed state of folder tracks after their "folder compact" mode has been changed.

    - For AUTOMATIC management of folders, turn this script on.  Its on/off state is global to REAPER, meaning it
      is either on or off for all open projects.
          -----------------------------------------------
          [Turn Automatic Folders on or off]
          -----------------------------------------------
          Runs a loop that essentially keeps invoking the [Convert current track layout to folder layout] script
          after a short timeout.

          NOTE: When running this script multiple times, you will see REAPER's "script is already running in the
                background" message.  Always select the "New instance" option.  The script itself tracks the current
                on/off state.  If you use the "Terminate instances" option, then the script can get confused about
                whether it's already running.  If that happens, invoking the script twice should correct things.

    - The various expand/collapse scripts all work regardless of whether you prefer MANUAL or AUTOMATIC control.

    - For a great user experience, the following keyboard shortcut assignments are recommended:
          ------------------------------------------------------------------
          SHORTCUT          |  SCRIPT
          ------------------+-----------------------------------------------
          CTRL +         `  |  Convert current track layout to folder layout
          ALT  +         `  |  Turn Automatic Folders on or off
          ------------------+-----------------------------------------------
          CTRL +         \  |  Toggle expansion state of selected folder(s)
          CTRL + SHIFT + \  |  Collapse all folders
          ALT  + SHIFT + \  |  Expand all folders
          ------------------+-----------------------------------------------
          CTRL +         /  |  Collapse selected folder(s)
          CTRL + SHIFT + /  |  Expand selected folder(s)
```