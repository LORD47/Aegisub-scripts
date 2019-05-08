script_name = "Select or Join lines"
script_description = "Select lines based on a given time interval between them"
script_author = "LORD47"
script_version = "1.0"

require 'inifile'
include("unicode.lua")

function setConfig()
 local str = showDialog('setconfig')
 
 -- we should test str value-> TBA
 
end

function selectTiming(subtitles, selected_lines, active_line)
       local idx = -1
       local sel_lines = {}
       local configFileData = {}	   
		
	   if(#selected_lines > 0)then idx = selected_lines[1] end

	   if(idx > -1 )then -- only one line is selected
	     local tmp_line = {}
		 configFileData = showDialog('load')		 
		 	 		 
		 -- time format: zzzz or [0]h:mm:ss.zz[0-9] or [0]h:mm:ss,zz[0-9] where [x] is optional
		 local time_str = configFileData['default']['time_gap']		 
		 local line_duration = configFileData['default']['line_duration']
		 
		 if(time_str ~= 'error')then 	  	  		  		  
		  
		  -- select first next subtitle line
		  local first_line = -1
		  local i = idx +1
		  		  		            		  
          while(first_line == -1 and i <= #subtitles)do
           tmp_line = subtitles[idx] 
		   local line = subtitles[i]
           configFileData.default.time_gap = tmp_line.end_time + time_str		   	  

           if(line.class == "dialogue" and (tmp_line.end_time - tmp_line.start_time <= line_duration) and
		      (line.end_time - line.start_time <= line_duration) and
		      line.start_time >= tmp_line.end_time and line.start_time <= configFileData['default']['time_gap'])then
			  
			first_line = i
			table.insert(sel_lines, idx)
			table.insert(sel_lines, first_line)			
		   else idx = i		   
 		        i = i +1
			   end		  		   
		   
  		  end -- end of: while(first_line = -1 and i <= #subtitles)
	     
	     end	 
		 
	     else aegisub.debug.out("Please select a line!") end  

return sel_lines
end


-- check config file exists
function configFileExists(fileName)
   file = io.open(fileName)
   if(file ~= nil)then file:close()end
return (file ~= nil)
end


-- create default config setup
function setDefaultSetup(fileName, keysValues)
   inifile.save(fileName, keysValues)   
end



-- config dialog window
function showDialog(op)
     local tmp_conf
	 local tmp_tbl
	 local cfg_res
	 local config = {}
	 local configFileData = {}
	 local tmp_str = ""
	 local fileName = aegisub.decode_path("?data/automation/autoload/") .. "/SelectJoinLinesConfig.ini"
	 
repeat


---
 tmp_conf = {}
 tmp_tbl = {}
 cfg_res = ""
 configFileData['default'] = {}
 configFileData['default']['time_gap'] = '1500' -- default value
 configFileData['default']['line_duration'] = '2000' -- default value
 configFileData['default']['lang_rtl'] = true -- default value
 
 
 if(configFileExists(fileName))then configFileData = inifile.parse(fileName)   
 else setDefaultSetup(fileName, configFileData) end
	 
	 
if(string.lower(op) == 'setconfig')then	 

    tmp_tbl = { class = "label"; label = "Select first line after current selected line with: " ;  x = 0; y = 0 ; height = 1; width = 1; }				 
    table.insert(tmp_conf, tmp_tbl )
 	  
 	-- time_gap
  	tmp_tbl = { name = "time_gap"; class = "edit"; x = 1; y = 0 ; height = 1; width = 7;
                 value = configFileData['default']['time_gap']; hint = "Next line to the selected line after this value amount will be selected";
 		  	  }
	table.insert(tmp_conf, tmp_tbl )

    tmp_tbl = { class = "label"; label = "First line with duration of: " ;  x = 0; y = 1 ; height = 1; width = 1; }				 
    table.insert(tmp_conf, tmp_tbl )
	
	-- line_duration
  	tmp_tbl = { name = "line_duration"; class = "edit"; x = 1; y = 1 ; height = 1; width = 7;
                 value = configFileData['default']['line_duration']; hint = "Lines duraion";
 		  	  }
      
    table.insert(tmp_conf, tmp_tbl )
 	
 	-- format label
 	tmp_tbl = { class = "label"; label = "Time in miliseconds" ;  x = 1; y = 2 ; height = 1; width = 1; }				 
    table.insert(tmp_conf, tmp_tbl )
	
	-- subtitle script language
	tmp_tbl = { name = "lang"; class = "checkbox"; label = "RTL language" ;  x = 0; y = 3 ; height = 1; width = 1; 
	           value = configFileData['default']['lang_rtl']}				 
    table.insert(tmp_conf, tmp_tbl )
 
 	----------    
 		
 	cfg_res, config = aegisub.dialog.display(tmp_conf, {"Save", "Help", "Close"} )		
 
 if( tostring(cfg_res) ~= "false" and string.lower(cfg_res) == "help")then showHelp() end
 
end -- end of: if(stirng.lower(op == 'load'))then

until( string.lower(op) == 'load' or tostring(cfg_res) == "false" or string.lower(cfg_res) == "close" or string.lower(cfg_res) == "save") 
 
----------- user clicked on a button from the previous menu ----------------------------
    if(tostring(cfg_res) == "false" or string.lower(cfg_res) == "close")then -- user closed the window
	 aegisub.cancel()	 	 
	 
	elseif( string.lower(cfg_res) == "save") then		 	
	 configFileData.default.time_gap = config['time_gap']
	 configFileData.default.line_duration = config['line_duration']
	 configFileData.default.lang_rtl = config['lang']
	 
     setDefaultSetup(fileName, configFileData)	 
    end	 

-----------------------------------------------------------------------------------------
	

return configFileData
	
end




-- Join two lines of the same actor
function joinSameActor(subtitles, selected_lines, active_line)
       local idx, idx2 = -1, -1
       local sel_lines = {}
       local configFileData = {}	   
		
	   if(#selected_lines > 1)then idx, idx2 = selected_lines[1], selected_lines[2] end

	   if(idx > -1 )then -- only one line is selected
		 configFileData = showDialog('load')		 		 	 		 
		 
		 local lang_rtl = configFileData['default']['lang_rtl']		 	  		  		            		  
         local line = subtitles[idx] 
		 local tmp_line = subtitles[idx2]   	  

         if(line.class == "dialogue" and tmp_line.class == "dialogue")then
          line.text = editLine(line, lang_rtl, true) .. '\\N' .. editLine(tmp_line, lang_rtl, true) 		  	   		   	  
		  line.end_time = tmp_line.end_time
		  subtitles[idx] = line
		  subtitles.delete(idx2)
		 end        		 
		 
	   end  -- if(idx > 1)

aegisub.set_undo_point("Join line/Same Actor")

end

-- Join two lines of different actors
function joinDiffActors(subtitles, selected_lines, active_line)
       local idx, idx2 = -1, -1
       local sel_lines = {}
       local configFileData = {}	   
		
	   if(#selected_lines > 1)then idx, idx2 = selected_lines[1], selected_lines[2] end

	   if(idx > -1 )then -- only one line is selected
		 configFileData = showDialog('load')		 		 	 		 
		 
		 local lang_rtl = configFileData['default']['lang_rtl']		 	  		  		            		  
         local line = subtitles[idx] 
		 local tmp_line = subtitles[idx2]   	  

         if(line.class == "dialogue" and tmp_line.class == "dialogue")then
		  if(lang_rtl)then
           line.text = editLine(line, lang_rtl, true) .. ' -\\N' .. editLine(tmp_line, lang_rtl, true) .. ' -'
		  
		  else line.text = '- ' .. editLine(line, lang_rtl, true) .. '\\N- ' .. editLine(tmp_line, lang_rtl, true)
		      end 
			  
          line.end_time = tmp_line.end_time 		  
		  subtitles[idx] = line
		  subtitles.delete(idx2)
		 end        		 
		 
	   end  -- if(idx > 1)

aegisub.set_undo_point("Join line/Same Actor")

end


--
function editLine(line, rtl, removeLBR)
      local tmpLn = line


	  
if(rtl)then
 -- removing line breaks
 if(removeLBR)then tmpLn.text = tmpLn.text:gsub("\\N", "، ")end
 --tmpLn.text = fix_punctuation(tmpLn.text)
 
else
     -- removing line breaks
     if(removeLBR)then tmpLn.text = tmpLn.text:gsub("\\N", ", ")end 
    end


return tmpLn.text
end


-- show help
function showHelp()
     local tmp_conf = {}

tmp_conf = {	 

    {
 	 class = "label";   x = 0; y = 0 ; height = 1; width = 1;
	 label = "Adjust time according to: " ;
    },

    {
 	 class = "label"; x = 1; y = 1 ; height = 1; width = 1;
	 label = "Format: Xh:mm:ss.zzY or Xh:mm:ss,zzY" ;
	},				 

	
    {
 	 class = "label";   x = 1; y = 2 ; height = 1; width = 1;
 	 label = "X : An optional 0 , Y : a digit ( but will be omitted)" ;
	}				 

	
}	-- of tmp_conf array

	aegisub.dialog.display(tmp_conf, {"OK"})		
end






-- scan & collect sytles from "dialogue" lines
function collect_styles_assumed(subtitles)
    local used_styles = {}
	local tmp = {}
	  
    for i = 1, #subtitles do
	 local line = subtitles[i]	  
     if(line.class == "dialogue") then
	 
      if(used_styles[line.style] == nil) then	  
 	   used_styles[line.style] = i
	   table.insert(tmp, line.style)	   
      end	  
	  
     end
    end
	
 return used_styles, tmp
end



-- update all checkbox state accroding to "st"
function sellect_all_none(conf, mode, name, nb, st)
 for i = 1, nb do
  if(string.lower(mode) == "n") then conf[name .. i] = st
  elseif(string.lower(mode) == "r") then conf[name .. i] = not(conf[name .. i]) end
 end
end



-- from time to string
function timeToString(time_v)
      local h, m, s = 0, 0, 0
      local ms = time_v % 1000
	  local tmp = intDiv(time_v , 1000)
      
	  h = intDiv(tmp , 3600)	    
      r = tmp % 3600
	  m = intDiv(r , 60)
      s = r % 60
	  
-- fomrat: h:mm:ss.zz i.e: 0:02:42.35
return string.format("%d:%.2d:%.2d%s%.2d", h, m, s, ".", ms)
end


function intDiv(v1, v2)
 local a, b, c = v1, v2, 0
 
 if(a < b) then c = 0
 else local d = a % b
      c = (a - d) / b
 end
 
return c 
end




-- lines will be selected based on their styles
function select_lines_by_styles(subtitles)    
	-- used_styles["style_name"] , styles[1]
    local j = 0	
	local selected_styles = {}
    local used_styles, styles = collect_styles_assumed(subtitles)	 	 

    local config = {}

repeat       
     local tmp_conf = {}
	 local tmp_tbl = {}
	 local tmp_v
	 local cfg_res	 
	
    --
	tmp_tbl = { class = "label"; label = "Apply to lines with the following selected styles:"
	           ; x = 0; y = 0 ; height = 1; width = 1; }				 
    table.insert(tmp_conf, tmp_tbl)


	
	local pos = 1
	
	for i=1, #styles do	
     -- checkbox to confirm selection
	 if(config["stl_ckbx_" .. i] ~= nil) then tmp_v = config["stl_ckbx_" .. i]
	 else tmp_v = true end
	 
	 tmp_tbl = { name = "stl_ckbx_" .. i ; class = "checkbox"; label = i .. "- ".. styles[i] ; 
   	             value = tmp_v; x = 0; y = i ; height = 1; width = 1 }				 
				 
     table.insert(tmp_conf, tmp_tbl )
	 
	 pos = pos + 1
    end

	
  cfg_res, config = aegisub.dialog.display(tmp_conf, {"Select All", "Select none", "Adjust", "Close"} )   
	
	if(tostring(cfg_res) == "false" )then -- user closed the window
	 aegisub.debug.out("\nCanceled.\n")
	 aegisub.cancel()
    elseif( string.lower(cfg_res) == "select all")then sellect_all_none(config, "n", "stl_ckbx_", #styles, true)
	elseif( string.lower(cfg_res) == "select none")then sellect_all_none(config, "n", "stl_ckbx_", #styles, false)
	elseif( string.lower(cfg_res) == "adjust") then
	
	 -- collect the selected styles	 	 
	 for i=1, #styles do	  
	  if(config["stl_ckbx_" .. i])then
	   selected_styles[ styles[i] ] = 0
	   j = j +1
	  end
     end
	 
	end
	
until (string.lower(cfg_res) == "close" or string.lower(cfg_res) == "adjust" )	
	
return selected_styles, j
	
end




------------------------------------------------------------------------------
function getTime(time_str)

    -- replace ',' of 'ms' with '.' (here it replace all occurences)
	local str = string.gsub(time_str, ',', '.')
	
    if(str == nil or type(str) ~= "string") then return 0 end -- not a string
	
    -- check for format [0]h:mm:ss.zz[0-9]    ,[x] -> x is optional
    local chunks = {str:match("^[^1-9]?(%d):(%d%d):(%d%d)%.(%d%d)[0-9]?$")}
    
    
return chunks;
end


-- trim string (whitespaces) on left & right
function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end



-- fix RTL languages punctuation
function fix_punctuation(lineTxt)

lookup = {['.'] = '‏.‏',
          [';'] = '؛‏' ,
          ['!'] = '‏!‏', 
          [']'] = ']‏', 
          ['['] = '‏]‏‏',
          [':'] = '‏:‏',
          ["«"] = '‏»‏',
          ['('] = '‏)‏‏‏', 
          [')'] = ')‏',
          ['»'] = '‏«‏',
          ['-'] = '‏-‏',
          ['"'] = '‏"‏', 
          ['،'] = '‏،‏'
         }

	
		--aegisub.debug.out(string.format('Processing line %d: "%s"\n', i, lineTxt))
		--aegisub.debug.out("Chars: \n")
		local in_tags = false
		local newtext = ""

		for c in unicode.chars(lineTxt) do
			--aegisub.debug.out(c .. ' -> ')
			if(c == "{")then in_tags = true	end

			if(in_tags)then
			 --aegisub.debug.out(c .. " (ignored, in tags)\n")
			 newtext = newtext .. c
			else
				if lookup[c] then
 				 --aegisub.debug.out(lookup[c] .. " (converted)\n")
				 newtext = newtext .. lookup[c]
				else
				    --aegisub.debug.out(c .. " (not found in lookup)\n")
					newtext = newtext .. c
				end

			end

			if(c == "}")then in_tags = false end

		end

return newtext
end


aegisub.register_macro("Select Lines/Config", script_description, setConfig)
aegisub.register_macro("Select Lines/Select", script_description, selectTiming)
aegisub.register_macro("Join Lines/Same Actor", script_description, joinSameActor)
aegisub.register_macro("Join Lines/Different Actors", script_description, joinDiffActors)

