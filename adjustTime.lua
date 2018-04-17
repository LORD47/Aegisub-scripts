script_name = "Adjust timing"
script_description = "Adjust timing"
script_author = "LORD47"
script_version = "1.0"


function adjustTiming(subtitles, selected_lines, active_line)
       local idx = -1
	   local h, m, s, z
	   local mode = "all lines" -- all lines, selected lines, from 1st selected line onward, from 1st selected line backward, styles
	   local stp_at, stp_at_val = false, 0
	   
	   local frst_ln = 0
	   
	   if(#selected_lines > 0)then idx = selected_lines[1] end
	   
	   if(idx > -1 )then -- at least one line is selected
	     frst_ln = getFirstRealIdx(subtitles) - 1
	     local line = subtitles[idx]
         local tmp_line = subtitles[idx-1]	-- to retreat the class of the line before the line Idx
		 local shift_type, shift_by_to, mode, stp_at_ckbx, stp_at_val = showDialog(idx, #selected_lines, #subtitles, tmp_line.class)

         shift_type = shift_type:gsub("^(%d+).*$", "%1")
		 shift_type = tonumber(shift_type)
		 

         if(mode == "selected lines")then stp_at_ckbx = false end		 
		 shift_by_to = trim(shift_by_to)
		 mode = string.lower(mode)
		 
		 -- time format:  [0]h:mm:ss.zz[0-9] or [0]h:mm:ss,zz[0-9] where [x] is optional
		 local time_str = getTime(shift_by_to) -- returns an array of [h, m, s, z]		 		 
		 
		 local line_nb, t, timecodes = 0, {}, {}
		 
		 if(stp_at_ckbx)then
		  line_nb, t = getLineNTime(trim(stp_at_val))
		  
		  timecodes = getTimecodes(t)
		  
		  line_nb = tonumber(line_nb)
		  
		  --aegisub.debug.out('stp_at_val = ' .. stp_at_val .. '\nline_nb = ' .. line_nb .. '\n[t1, t2] = ' )
		  --for j = 1, #timecodes do aegisub.debug.out(timecodes[j] .. ', ') end
		  
		  --aegisub.debug.out('\n')
		 end
		 
		 if(#time_str == 4)then 
		  
		  h, m, s, z = time_str[1], time_str[2], time_str[3], time_str[4]		  
		  shift_by_to = string.format("%d:%.2d:%.2d%s%.2d", h, m, s, ".", z)
		  
		  -- shift_by = (h * 60 * 60 * 1000) + (m * 60 * 1000) + (s * 1000) + z
		  local shift_by = (h * 60 * 60 * 1000) + (m * 60 * 1000) + (s * 1000) + (z*10)
		  	  		  
		  
		  if(shift_type == 1)then	
		   local bf = "Forrward (+): "
		   shift_by = shift_by - line.start_time 
		   local tmp_shft = shift_by
		  
           if(shift_by < 0)then
 		    bf = "Backward (-): "
            tmp_shft = -1 * shift_by
		   end
		   
           aegisub.debug.out("Adjust according to: " .. timeToString(line.start_time) .. " -> " .. shift_by_to .. "\n")		   
           aegisub.debug.out("-> " .. bf .. timeToString(tmp_shft)  .. "\n")		   
		 
          elseif(shift_type == 2)then
		   aegisub.debug.out("Shift by : +" .. timeToString(shift_by)  .. "\n")
		   
          elseif(shift_type == 3)then
		   aegisub.debug.out("Shift by : -" .. timeToString(shift_by)  .. "\n")
		   shift_by = -1 * shift_by 		   
          end
		  
          aegisub.debug.out("Applied on: " .. mode .. "\n")
		  
		  -- adjust subtitles
		  local nbLines, nbAdjs, line_idx = 0, 0, 0
		  local des_asc = 1
		  
		  if(mode == "from 1st selected line backward")then des_asc = -1 end
		  
		  if(mode == "all lines" or mode:match("from 1st selected"))then -- all lines, 1st sel onward/backward			 
           --aegisub.debug.out("frst_ln = %d \n", frst_ln)
           local n = #subtitles  
		   
		   if(mode == "all lines")then idx = 1
		   elseif(mode == "from 1st selected line backward")then n = frst_ln + 1 end
		   
		   for i = idx, n, des_asc do
		    local line = subtitles[i]

		    if(stp_at_ckbx and frst_ln >= 0 and line_nb > 0 and (des_asc * i > des_asc * (frst_ln + line_nb) ) )then 
 			 aegisub.debug.out("Stop @line: %d (not included)\n", i-frst_ln)
 			 break;
			end
			
            if(line.class == "dialogue" and inInterval(timecodes, line.start_time)) then --aegisub.debug.out("i = %d \n", i-frst_ln)
			 nbAdjs = nbAdjs + 1
			 line.start_time = line.start_time + shift_by
			 line.end_time = line.end_time + shift_by
			 
			 subtitles[i] = line
			end
		   end
		   aegisub.debug.out("Adjusted: %d line(s).\n", nbAdjs)
		   
		  elseif(mode == "selected lines")then -- selected lines
		  
		   for i= 1, #selected_lines do
		    local line = subtitles[ selected_lines[i] ]	  

			 nbAdjs = nbAdjs + 1
			 line.start_time = line.start_time + shift_by
			 line.end_time = line.end_time + shift_by
			 
			 subtitles[ selected_lines[i] ] = line
		   end
		   aegisub.debug.out("Adjusted: " .. nbAdjs .. " line(s)." .. "\n")
		   
		  elseif(mode == "styles")then
		   local sel_styles, nb = select_lines_by_styles(subtitles)
		   
		   if(nb > 0)then
		    
		    for i = frst_ln + 1, #subtitles do
		     local line = subtitles[i]

		     if(stp_at_ckbx and frst_ln >= 0 and line_nb > 0 and (des_asc * i > des_asc * (frst_ln + line_nb) ) )then 
			  aegisub.debug.out("Stop @line: %d (not included)\n", i-frst_ln)
			  break;
			 end
			
             if(line.class == "dialogue" and inInterval(timecodes, line.start_time)) then --aegisub.debug.out("i = %d \n", i-frst_ln)
			  nbLines = nbLines + 1
			  
			  if(sel_styles[line.style] ~= nil)then
			   nbAdjs = nbAdjs + 1
			   sel_styles[line.style] = sel_styles[line.style] + 1
			   line.start_time = line.start_time + shift_by
			   line.end_time = line.end_time + shift_by
			 
			   subtitles[i] = line
			  end 
			  
			 end			 
		    end
			aegisub.debug.out("Adjusted: %d/%d \n", nbAdjs, nbLines)
			
			for i, v in pairs(sel_styles)do aegisub.debug.out("Style: %s -> %d line(s) \n", i, v) end
			
		   end
		   
		  end		  
		 
		  else aegisub.debug.out("Invalid time string format!\n")
		  
		 end 		 
		 
	   else aegisub.debug.out("Please select a line!") end

aegisub.set_undo_point("Adjust timing")	   
end





-- prepare config
function showDialog(frstIdx, nbSlctd, nbSubs, prvLineClass)
     local tmp_conf
	 local tmp_tbl
	 local cfg_res
	 local config = {}
	 local tmp_str = ""
	 
	 -- adjust mode    1            2                 3                                4                                 5
	local modes = {"All lines", "Selected lines", "From 1st selected line onward", "From 1st selected line backward", "Styles"}
	local tmp_mode = modes[1]
	local mode_val = modes[1]
	
	-- shift type             1               2                   3   	                          
	local shift_type = {"1-Shift to:", "2-Shift by (+):", "3-Shift by (-):"}
	local tmp_shift_type = shift_type[1]
	

repeat

---
 tmp_conf = {}
 tmp_tbl = {}
 cfg_res = ""

if(config["shift_type"] ~= nil) then tmp_shift_type = config["shift_type"] end
 
if(config["shift_by"] ~= nil) then tmp_str = config["shift_by"] end
	
	-- shift type
	tmp_tbl = { name = "shift_type"; class = "dropdown"; x = 0; y = 0; height = 1; width = 1;
 	            items = shift_type; value = tmp_shift_type }	
				
    table.insert(tmp_conf, tmp_tbl )
	  
	-- edit zone for the default styles	
 	tmp_tbl = { name = "shift_by"; class = "edit"; x = 1; y = 0 ; height = 1; width = 7;
                value = tmp_str; hint = "Time shifting is based on this value";
		  	  }
     
    table.insert(tmp_conf, tmp_tbl )
	
	-- format label
	tmp_tbl = { class = "label"; label = "Format: Xh:mm:ss.zzY or Xh:mm:ss,zzY" ;  x = 1; y = 1 ; height = 1; width = 1; }				 
    table.insert(tmp_conf, tmp_tbl )
	
    tmp_tbl = { class = "label"; label = "X : An optional 0 , Y : a digit ( but will be omitted)" ;  x = 1; y = 2 ; height = 1; width = 1; }				 
    table.insert(tmp_conf, tmp_tbl )	
	
		
	------ select "mode" based on nb selected lines and first selected line position 
	-- to make the life easier for the user that's all 
	
    if(config["mode"] ~= nil) then mode_val = config["mode"] -- user went to and returned from "Help" dlg
	else
	    if(nbSlctd > 1)then mode_val = modes[2] -- more than one line are selected, mode -> 2	
        else
         	if(frstIdx == nbSubs)then mode_val = modes[4] -- last line is selected, mode -> 4
            elseif(string.lower(prvLineClass) ~= "format")then		
        	 mode_val = modes[3] -- in between line is selected, mode -> 3 
            end
        end
	end
	------
	
	tmp_tbl = { class = "label"; label = "Use shift value and apply it on: " ;  x = 0; y = 3 ; height = 1; width = 1; }				 
    table.insert(tmp_conf, tmp_tbl )
	
	tmp_tbl = { name = "mode"; class = "dropdown"; x = 1; y = 3 ; height = 1; width = 1;
 	              items = modes; value = mode_val }
     
    table.insert(tmp_conf, tmp_tbl )



    --- stops @line or line_starts in [t1, t2] or both
	tmp_tbl = { name = "stop_at_ckbx"; class = "checkbox"; label = "Stop at this line or line_time_start in [t1, t2] or both: " ;  x = 0; y = 4 ; height = 1; width = 1; }				 
    table.insert(tmp_conf, tmp_tbl )
	
	tmp_tbl = { name = "stop_at"; class = "edit"; x = 1; y = 4 ; height = 1; width = 1;
 	              hint = 'Type: line_number or/and two seperated timecodes'}
	table.insert(tmp_conf, tmp_tbl )
	   				  
    tmp_tbl = { class = "label"; label = "Example: 7 or/and 0:01:23.45 0:02:34.56 \n The timecode format is the same as above." ;  x = 1; y = 5 ; height = 1; width = 1; } 
    table.insert(tmp_conf, tmp_tbl )
	----------    
		
	cfg_res, config = aegisub.dialog.display(tmp_conf, {"Adjust", "Help", "Close"} )		

if( tostring(cfg_res) ~= "false" and string.lower(cfg_res) == "help")then showHelp() end

until( tostring(cfg_res) == "false" or string.lower(cfg_res) == "close" or string.lower(cfg_res) == "adjust") 
 
----------- user clicked on a button from the previous menu ----------------------------
    if(tostring(cfg_res) == "false" or string.lower(cfg_res) == "close")then -- user closed the window
	 aegisub.cancel()	 	 
	 
	elseif( string.lower(cfg_res) == "adjust") then
	 tmp_shift_type = config["shift_type"]
	 tmp_str = config["shift_by"]
	 tmp_mode = config["mode"]
	 stp_at = config["stop_at_ckbx"]
	 stp_at_val = config["stop_at"]
    end	 

-----------------------------------------------------------------------------------------
	

return tmp_shift_type, tmp_str, tmp_mode, stp_at, stp_at_val
	
end




-- show help
function showHelp()
     local tmp_conf = {}

tmp_conf = {	 

    {class = "label"; x = 0; y = 0; height = 1; width = 1; label = "Adjust time according to: " ;},

    {class = "label"; x = 1; y = 1; height = 1; width = 1; label = "Format: Xh:mm:ss.zzY or Xh:mm:ss,zzY";},				 
	
    {class = "label"; x = 1; y = 2; height = 1; width = 1; label = "X : An optional 0 , Y : a digit ( but will be omitted)";}				 
	
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
	  local tmp = intDiv(time_v, 1000)
      
	  h = intDiv(tmp, 3600)	    
      r = tmp % 3600
	  m = intDiv(r, 60)
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
	 
	 tmp_tbl = { name = "stl_ckbx_" .. i; class = "checkbox"; label = i .. "- ".. styles[i]; 
   	             value = tmp_v; x = 0; y = i ; height = 1; width = 1 }				 
				 
     table.insert(tmp_conf, tmp_tbl)
	 
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
function getFirstRealIdx(subs)
       for i = 1, #subs do
	    local line = subs[i]			
		if(line.class == "dialogue" or line.class == "comment")then return i end
       end	   
end

function getTime(time_str)

    -- replace ',' of 'ms' with '.' (here it replaces all occurences)
	local str = string.gsub(time_str, ',', '.')
	
    if(str == nil or type(str) ~= "string") then return 0 end -- not a string
	
    -- check for format [0]h:mm:ss.zz[0-9]    ,[x] -> x is optional
    local chunks = {str:match("^0?(%d):(%d%d):(%d%d)%.(%d%d)%d?$")}
    
    
return chunks;
end



function timeToInteger(time_str)
     local t = getTime(time_str)
	 
     -- h, m, s, z = t[1], t[2], t[3], t[4]	 
return (t[1] * 60 * 60 * 1000) + (t[2] * 60 * 1000) + (t[3] * 1000) + (t[4] * 10);
end



function getLineNTime(time_str)

    -- replace ',' of 'ms' with '.' (here it replaces all occurences)
	local str = string.gsub(time_str, ',', '.')

    if(str == nil or type(str) ~= "string") then return -1, {} end -- not a string 

    -- check for format [0]h:mm:ss.zz[0-9]    ,[x] -> x is optional
    _, pos, line_nb = str:find("^(%d+)$")

    local timecodes = {}

	if(line_nb == nil)then
     _, pos, line_nb = str:find("^(%d+)%s+")

	 if(pos == nil)then str2 = ' ' .. str
	 else str2 = ' ' .. str:sub(pos) end

	 for t in str2:gmatch("%s+0?(%d:%d%d:%d%d%.%d%d)%d?")do
	  table.insert(timecodes, t)
     end

	end -- end of: if(line_nb == nil)
	
    if(line_nb == nil)then line_nb = -1	end
	
return line_nb, timecodes
end


function getTimecodes(t)
      local tmp = {}	  
      for i = 1, #t do table.insert(tmp, timeToInteger(t[i])) end	  
	  table.sort(tmp)

 return  tmp
end


--
function checkThisLine(filter, current, frst_ln, idx, line_max, t, brk_excld)
 -- brk_excld = 0 -> break, 1 -> exclude
 if(filter)then
  if(brk_excld == 0 and frst_ln > 0 and line_max > 0 and idx > frst_ln + line_max)then return true
  elseif(brk_excld == 1 and not inInterval(t, current.start_time))then return true   
  else return false end
  
 else return false end 
end



function inInterval(t, val)
    if(#t > 0)then	
	 local i, n, tr = 2, #t, false
	 	 
	 while(i <= n and not tr)do	  
	  if(val >= t[i-1] and val <= t[i])then tr = true
	  else i = i + 2 end
	 end
	 
	 if(not tr and n % 2 == 1 and val >= t[n])then tr = true end
	 
	 return tr
	 
	else return true end
end


-- trim string (whitespaces) on left & right
function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

aegisub.register_macro(script_name, script_description, adjustTiming)

