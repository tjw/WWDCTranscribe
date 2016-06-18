(*
With a QuickTime file open, and an OmniOutliner file open that matches the title below, if this is invoked:

- If the QT file is playing, it is paused
  - If there is not a row starting with the right session number, one is created at the top level (with a link back to the QT file)
  - A new row is added with the current time code and the insertion point to the right of it and OmniOutliner is activated.
  
- Otherwise, playing in the QT file is resumed and QT is activated

- Setup:
	- Hook this up to a command key using FastScripts <https://red-sweater.com/fastscripts/> to make taking notes from WWDC session videos easier.
	- Open System Preferences, "Security & Privacy"
	- Select the "Privacy" tab
	- Select the "Accessiblity" entry in the left-hand list
	- Enable or add "FastScripts" to the list of applications (needed to press the right arrow key below).


*)

set WWDCNotesFileName to "WWDC 2016 Notes"
set SkipBackSeconds to 2.0 -- How many seconds to skip backwards when resuming after taking a note.

property StoredPlaybackRate : 1.0
property StoredPlaybackTime : 0.0

--
--
--


on twoDigitString(theValue)
	--log "value: " & theValue
	if theValue as number < 10 then
		return "0" & (theValue as string)
	end if
	return theValue as string
end twoDigitString

on concatTimeComponent(base, value)
	if base is "" then
		if value is 0 then
			return ""
		end if
		return twoDigitString(value)
	end if
	
	return base & ":" & twoDigitString(value)
end concatTimeComponent

on timeString(theHours, theMinutes, theSeconds)
	set theResult to ""
	set theResult to concatTimeComponent(theResult, theHours)
	set theResult to concatTimeComponent(theResult, theMinutes)
	
	-- Don't report bare seconds.
	if theResult is "" then
		set theResult to "00"
	end if
	
	set theResult to concatTimeComponent(theResult, theSeconds)
	return theResult
end timeString

on timeStringFromSeconds(theSeconds)
	set theTime to theSeconds
	
	set theHours to round of (theTime / 3600) rounding down
	set theTime to theTime - theHours * 3600
	
	set theMinutes to round of (theTime / 60) rounding down
	set theTime to theTime - theMinutes * 60
	
	set theSeconds to theTime as integer
	
	my timeString(theHours, theMinutes, theSeconds)
end timeStringFromSeconds

on sessionIdentifierFromName(theName)
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to {"_"}
	set sessionIdentifier to text item 1 of theName
	set AppleScript's text item delimiters to oldDelims
	return sessionIdentifier
end sessionIdentifierFromName

tell application "QuickTime Player"
	tell front document
		set isPlaying to its playing
		--set isPlaying to true
		
		if isPlaying then
			set StoredPlaybackRate to its rate
			pause
			
			set theTime to current time
			set StoredPlaybackTime to theTime
			
			set theTimeString to my timeStringFromSeconds(theTime)
			set theFile to its file
			set theTitle to its name
		else
			-- Invoked again; end editing the current note and start playing again.
			tell app "OmniOutliner"
			tell document WWDCNotesFileName
				select {}
				end
			end tell
			activate
			
			if SkipBackSeconds < current time then
				set current time to current time - SkipBackSeconds
			end if
			
			play
			set rate to StoredPlaybackRate
			set StoredPlaybackTime to 0.0
			
			return
		end if
		
	end tell
end tell

on require_ui_scripting()
	tell application "System Events"
		if UI elements enabled is false then
			error "UI Scripting not enabled!"
		end if
	end tell
end require_ui_scripting


on press_right_arrow()
	my require_ui_scripting()
	
	tell application "OmniOutliner" to activate -- App must be front
	delay 0.25
	tell application "System Events"
		tell process "OmniOutliner"
			key code 124 using {command down}
		end tell
	end tell
	delay 0.25
end press_right_arrow


tell application "OmniOutliner"
	set theDocument to document WWDCNotesFileName
	if theDocument is missing value then
		display alert "No notes document found."
		return
	end if
	
	tell theDocument
		-- Get or make a heading row for the notes for this session
		try
			set sessionRow to first row whose topic begins with my sessionIdentifierFromName(theTitle)
		on error
			-- First note for this session; make the row and focus on it.
			set sessionRow to make new row with properties {topic:theTitle} at end of its rows
			
			hoist sessionRow
			
			-- Set the title's link (which won't be very nice looking, sadly, since the filename is all lowercase with underscores).
			set value of attribute "link" of style of topic of sessionRow to theFile
		end try
		
		-- Add a new note row with the time code
		set theNoteRow to make new row with properties {topic:"[" & theTimeString & "] "} at end of rows of sessionRow
		set expanded of sessionRow to true
		
		-- BUG: OmniOutliner doesn't seem to be sorting rows by rank immediately when we immediately edit it (which intentionally prevents sorting), so w/o this the row appears at the top of the list of children until you end editing.
		delay 0.05
		
		select topic cell of theNoteRow -- Selects all the text, sadly; we want the insertion point to the right
		
		-- Use UI scripting to move the cursor
		my press_right_arrow()
	end tell
	
end tell
