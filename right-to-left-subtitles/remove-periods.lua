script_name = "Fix single points"
script_description = "Fix all single points (regardless of its position )"
script_author = "LORD47"
script_version = "1.1"

include("unicode.lua")
include("utf8.lua")
--include("utf8-2.lua")
unicode = require 'aegisub.unicode'
re = require 'aegisub.re'

function removePoints(subtitles, selected_lines, active_line)
    local bfr =  { ["N"]="", ["("]="", [")"]="", ["'"]="", ['"']="" }
    local dialogue = {}
	local t_mp, r_mp = {}, {}
	local nb, idx = 0, 0
	local sel_lines = {}
	local str = ""
	local s1, s2 = ".", "،"

	s1, s2 = showDialog(s1, s2)

	local LastLnIdx = #subtitles

    for i = 1, #subtitles do	
     local line = subtitles[i]

     if(line.class == "dialogue") then
	  idx = idx +1

	  local tags, s = line.text:match("(%{[^}]+%})(.+)")
	  if(tags == nil)then
 	   tags = ""
	   s = line.text
	  elseif(s == nil)then s = "" end

      str = trim(s)

	  -- if(idx == 5)then
	   -- tmp_idx = 0
	  -- for c in unicode.chars(str) do
		-- tmp_idx = tmp_idx + 1
	   -- aegisub.debug.out(string.format("c[%d] = %s\n", tmp_idx, c))
	  -- end
	  -- end

	  str = re.sub(str, "(?<!^)(?<![.])[.]{1}(?![\\.\\w\\d\\s\\!\\؟\\(\\)]+)", '')

	  -- lookup for multiple successive points (which will be ignored)
	  local j, k = string.find(str, '%.+')

	  while(j ~= nil)do -- we found "point(s)" in this line
		str = trim(str)

	   if(j == k )then -- single character

	    if(j == 1)then -- @ end of the sentence		
		 -- if there's a line break -> replace it with "a comma" otherwise remove it
		 if(string.find(str, '%-') ~= nil)then
			str = string.gsub(str, "%.", "", 1) -- 2 actors dialogue -> Remove
	     elseif(string.find(str, '%\\N') ~= nil)then
			str = string.gsub(str, "%.", s2, 1) --> Replace
	 	 else str = string.gsub(str, "%.", "", 1)	end

		elseif(j < string.len(str))then -- @ middle of the sentence
		 local pos, tr = 1, false
		 -- find the "." position, because "j" is number of bytes
		 while( (pos <= j)and(not tr) ) do
	      if(string.utf8sub(str, pos, pos) == "." ) then tr = true
		  else pos = pos + 1 end
	     end

		 local tmp = string.utf8sub(str, pos - 1, pos - 1)

		 if(bfr[tmp] ~= nil)then str = string.gsub(str, "%.", "", 1)
		 else str = string.gsub(str, "%.", s2, 1) end

		else -- @ the end of the sentence 
		 str = string.gsub(str, "%.", "", 1)
		end

	   else -- multiple points
	    local mp = string.sub(str , j, k)
		local ptrn = "(" .. string.gsub(mp, "%.", "%%.") .. ")"

		if(t_mp[ string.len(mp) ] == nil)then
 		 t_mp[string.len(mp)] = "x" .. string.len(mp)
		 r_mp[string.len(mp)] = string.gsub(mp, "%.", "%%.")
		end

		str = string.gsub(str, ptrn, "x" .. string.len(mp), 1 )
	   end

	   j, k = string.find(str, '%.+')

	  end -- end: while(j ~= nil)

	  for x, v in pairs(t_mp) do
	   str = string.gsub(str, v, r_mp[x])
	  end

	  if(line.text ~= str)then
       line.text = tags .. str
	   subtitles[i] = line
	   nb = nb + 1
	   table.insert(sel_lines, i)
	  end

     end -- end: if(line.class == "dialogue")

    end -- end: for i = 1,#subtitles

aegisub.debug.out("\n---------------------------\n" .. nb .. " point(s) removed.\n")
if(#sel_lines == 0)then sel_lines = selected_lines end

aegisub.set_undo_point("Remove single point")
--return sel_lines
end

-- get lookups
function showDialog(s1, s2)
     local tmp_conf = {}
	 local tmp_tbl = {}
	 local cfg_res
	 local config = {}
	 local tmp1, tmp2 = s1, s2

    tmp_tbl = { class = "label"; label = "Lookup: " ;  x = 0; y = 0 ; height = 1; width = 1; }
    table.insert(tmp_conf, tmp_tbl )

	-- edit zone for character_to_be_removed
 	tmp_tbl = { name = "l1"; class = "edit"; x = 1; y = 0 ; height = 1; width = 2;
                value = s1; hint = "Character to be removed"
		  	  }

    table.insert(tmp_conf, tmp_tbl )

	tmp_tbl = { class = "label"; label = "Replace with: " ;  x = 0; y = 1 ; height = 1; width = 1; }
    table.insert(tmp_conf, tmp_tbl )

	-- edit zone for replae_with_character
 	tmp_tbl = { name = "l2"; class = "edit"; x = 1; y = 1 ; height = 1; width = 2;
                value = s2; hint = "Character to replace when it's necessary"
		  	  }

    table.insert(tmp_conf, tmp_tbl )

	cfg_res, config = aegisub.dialog.display(tmp_conf, {"Continue", "Close"} )

----------- user clicked on a button from the previous menue ----------------------------
    if(tostring(cfg_res) == "false" or string.lower(cfg_res) == "close")then -- user closed the window
	 aegisub.cancel()
	elseif( string.lower(cfg_res) == "continue") then
	 tmp1 = config["l1"]
	 tmp2 = config["l2"]
    end
-----------------------------------------------------------------------------------------

 return tmp1, tmp2
end

-- trim strng (whitespaces) on left & right
function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

aegisub.register_macro(script_name, script_description, removePoints)
