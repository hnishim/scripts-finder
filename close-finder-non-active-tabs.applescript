tell application "Finder"
	activate
	-- close Finder window id 52037
	
	set frontWindow to window 1
	
	try
		set windowCount to count of Finder windows
		log windowCount
		if windowCount ² 1 then
			return
		end if
	on error
		return
	end try
	
	repeat with i in id of Finder windows
		close Finder window id i
	end repeat
end tell
