# 1つ下のフォルダ内のファイルを別フォルダにコピー
on run
	tell application "Finder"
		set originFolder to choose folder
		set destinationFolder to choose folder

		set folderList to every folder of originFolder

		repeat with targetFolder in folderList
			repeat with currentItem in targetFolder
				duplicate currentItem to destinationFolder
			end repeat
		end repeat

	end tell
end run
