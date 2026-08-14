on run {}
	tell application "Finder"
		try
			set currentFolder to insertion location as alias
			set filePath to (POSIX path of currentFolder) & "署名済みのドキュメントへのリンク.txt"
			set clipboardText to the clipboard as text
			set fileReference to open for access POSIX file filePath with write permission
			set eof of fileReference to 0
			write clipboardText to fileReference as «class utf8»
			close access fileReference
		on error
			display notification "Failed to create file." with title "Error"
		end try
	end tell
end run