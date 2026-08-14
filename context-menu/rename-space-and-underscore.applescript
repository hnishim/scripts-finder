on run {input, parameters}

	tell application "Finder"
		set selectedItems to selection
		if selectedItems is {} then
			display dialog "ファイルまたはフォルダが選択されていません。" buttons {"OK"} default button "OK" with title "エラー" with icon stop
			return
		end if
	end tell

	repeat with thisItem in selectedItems
		tell application "Finder"
			try
				set currentName to name of thisItem
				if currentName does not contain " " then
					return
				end if
				set newName to my replace_chars(currentName, "_", "-")
				set newName to my replace_chars(newName, " ", "_")
				if newName is not currentName then
					set name of thisItem to newName
				end if

			on error errMsg number errNum
				display dialog "ファイル「" & currentName & "」の名前変更中にエラーが発生しました。" & return & return & "エラー詳細: " & errMsg & " (" & errNum & ")" buttons {"OK"} default button "OK" with title "リネームエラー" with icon caution
			end try
		end tell
	end repeat

	return input
end run

on replace_chars(this_text, search_string, replace_string)
	set AppleScript's text item delimiters to search_string
	set the item_list to text items of this_text
	set AppleScript's text item delimiters to replace_string
	set this_text to the item_list as string
	set AppleScript's text item delimiters to ""
	return this_text
end replace_chars
