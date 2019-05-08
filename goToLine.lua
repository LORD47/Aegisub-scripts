script_name = "Go to line"
script_description = "Go to line of specified number"
script_author = "LORD47"
script_version = "2.0"

re = require 'aegisub.re'


-- Go to line
function goToLine(subtitles, selected_lines, active_line)
       local sel_lines = {}
       local configFileData = {}	   
	   local str = showDialog() -- returns number or time preceded by +/-/*/ or just time

	   local actionType, val, up_dw
	   
	   local firstChar = string.sub(str, 1, 1);
	   
	   if(firstChar == "+" or firstChar == "-" or firstChar == "*")then
	    up_dw = firstChar
	    actionType, val = parseValue(string.sub(trim(str), 2))

	   else up_dw = '*'
            actionType, val = parseValue(str)	   
	   end	
	   
		
       if(actionType == nil)then aegisub.debug.out('Invalid input!')  
	   elseif(string.lower(actionType) == 'line')then
	   
	    if(val > -1 )then -- valid line number		 		 	 		 
		 local i, fstLnPos = 1, 0

         -- find the first line number in subtitles grid
         while(i <= #subtitles and val ~= fstLnPos)do
		  local line = subtitles[i]		 
		
          if(line.class == "dialogue" or line.class == "comment")then
            fstLnPos = fstLnPos + 1
		  end        		 
		 
		  if(val == fstLnPos)then  table.insert(sel_lines, i)		 
          else i = i + 1 end		 	 
		 
		 end 
		
	    end  -- if(val > -1)

       elseif(string.lower(actionType) == 'time')then		
	    --
		 local i, fstLnPos, max_val, tr = 1, -1, 0, false
		 local step = 1
		 
		 if(up_dw ~= '*')then

		  if(#selected_lines > 0)then		   	   
		   if(up_dw == '-')then step = -1 end

           max_val = subtitles[ selected_lines[1] ].start_time + 1 -- +1 -> to make the line[i] selected when its start_time is equal to the current selected_line.start_time
		   i = selected_lines[1] + step
		  end
		 end
		  

         while(i >= 1 and i <= #subtitles and not tr)do
		  local line = subtitles[i]		 
		  
          if(line.class == "dialogue" or line.class == "comment")then
           if(line.start_time == val)then tr = true
		   elseif(math.abs(line.start_time - val) < math.abs(max_val - val))then
 		    max_val = line.start_time
			fstLnPos = i
		   end
		   
		  end        		 
		 
		  if(tr)then table.insert(sel_lines, i)		 
          else i = i + step end		 	 
		 
		 end 		

		 if(not tr and fstLnPos > -1)then table.insert(sel_lines, fstLnPos) end		 
		--
       end
	   
return sel_lines

end


-- config dialog window
function showDialog()
     local tmp_conf
	 local tmp_tbl
	 local cfg_res
	 local config = {}
	 local configFileData = {}
	 local line_id = -1
	 
repeat
---
 tmp_conf = {}
 tmp_tbl = {}
 cfg_res = ""
	 
    tmp_tbl = { class = "label"; label = "Go to line:" ;  x = 0; y = 0 ; height = 1; width = 1; }				 
    table.insert(tmp_conf, tmp_tbl )
 	  
 	-- line_nb
  	tmp_tbl = { name = "line_nb"; class = "edit"; x = 1; y = 0 ; height = 1; width = 7;
                 hint = "Specify the line number";
 		  	  }
	table.insert(tmp_conf, tmp_tbl ) 
 	----------    
 		
 	cfg_res, config = aegisub.dialog.display(tmp_conf, {"Select", "Help", "Close"} )		  
	
 if( tostring(cfg_res) ~= "false" and string.lower(cfg_res) == "help")then showHelp() end	

until( tostring(cfg_res) == "false" or string.lower(cfg_res) == "close" or string.lower(cfg_res) == "select") 
 
----------- user clicked on a button from the previous menu ----------------------------
    if(tostring(cfg_res) == "false" or string.lower(cfg_res) == "close")then -- user closed the window
	 aegisub.cancel()	 	 
	 
	elseif( string.lower(cfg_res) == "select") then		 	
     line_id = trim(config['line_nb'])
    end	 

-----------------------------------------------------------------------------------------
	

return trim(line_id)
	
end




function parseValue(val)
 local matches
 local actionType, nb
 local lineTime_val = 0

 matches = re.match(trim(val), '^(\\d+)$')  
  
 if(matches ~= nil)then
  nb = matches[1].str 
  actionType = 'line'
  lineTime_val = lineTime_val + tonumber(nb)
           
 else 
      -- match (01?) :.s+ (01?) :.s+ (01?) :.s+ (012?)   , () -> presents captures
      -- ? -> optional
	  -- :.?s+ -> one of these with s+ -> one/mulitple spaces
	  
      -- ex: 01:47:52:012
      -- ex   1 47 52 012
	  -- ex   1 47.52   012
      matches = re.match(trim(val), '^(\\d{1,2})(?:[:\\.]|[\\s]+)(\\d{1,2})(?:[:\\.]|[\\s]+)(\\d{1,2})(?:[:\\.]|[\\s]+)(\\d{1,3})$')
	  
	  -- Things could've been easier if re module works as real regex modules do
	  -- so I wouldn't have to write these extra lines when I just could've done some logical conditions test instead of typing the same shit twice
      if(matches ~= nil)then
	   actionType = 'time'      	   
	   
	   if(validateValue(matches[2].str, nil) and validateValue(matches[3].str, 60) and validateValue(matches[4].str, 60) and validateValue(matches[5].str, 1000))then

		lineTime_val = lineTime_val + (tonumber(matches[2].str) * 1000 * 60 * 60) -- hours
		lineTime_val = lineTime_val + (tonumber(matches[3].str) * 1000 * 60 )     -- minutes
		lineTime_val = lineTime_val + (tonumber(matches[4].str) * 1000)           -- seconds
    
	    local ms = tonumber(matches[5].str)		
		
		if(ms < 100)then ms = ms * 10 end

	    lineTime_val = lineTime_val + ms
		
	   else return nil, 0	
	   end
	 
      else
	   -- match (01?) :.s+ (01?)  , () -> presents captures
	   -- ? -> optional
	   -- :.?s+ -> one of these with s+ -> one/mulitple spaces
       matches = re.match(trim(val), '^(\\d{1,2})(?:[:\\.]|[\\s]+)(\\d{1,2})$')
       
       if(matches ~= nil)then
        actionType = 'time'
           
        if(validateValue(matches[2].str, 60) and validateValue(matches[3].str, 60))then		 
		 lineTime_val = lineTime_val + (tonumber(matches[2].str) * 1000 * 60)  -- minutes
		 lineTime_val = lineTime_val + (tonumber(matches[3].str) * 1000)       -- seconds
		 
	    else return nil, 0 end
	   
	  end 
	  ----------
     end 

 end

return actionType, lineTime_val
end



-- trim string (whitespaces) on left & right
function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end


function validateValue(val, maxVal)
  if(maxVal == nil)then return (val ~= nil)
  else return ( (val ~= nil) and (tonumber(val) < tonumber(maxVal)) ) end
end



-- show help
function showHelp()
     local tmp_conf = {}

tmp_conf = {	 

    {class = "label"; x = 0; y = 0; height = 1; width = 1; label = 'Using "Line number" or "Line start_time" :' ;},
    {class = "label"; x = 0; y = 1; height = 1; width = 1; label = '"Line start_time" format: hh*mm*ss*zzz or mm*ss  (find the exact/closest value)';},
    {class = "label"; x = 1; y = 2; height = 1; width = 1; label = 'hh: hours, mm: minutes, ss: seconds, zzz : milliseconds';},
    {class = "label"; x = 1; y = 3; height = 1; width = 1; label = '*: could be a ":" or a "." or single/multiple spaces or mixed';},
    {class = "label"; x = 1; y = 4; height = 1; width = 1; label = 'hh, mm, ss: are of 1-2 digits while zzz : are of 1-3 digits';},
    {class = "label"; x = 1; y = 5; height = 1; width = 1; label = 'Input that starts with "+" means "Find next"';},
    {class = "label"; x = 1; y = 6; height = 1; width = 1; label = 'Input that starts with "-" means "Find previous"';},
    {class = "label"; x = 1; y = 8; height = 1; width = 1; label = 'Examples:';},
    {class = "label"; x = 1; y = 9; height = 1; width = 1; label = 'I) by "Line number": 120 (find Line 120)';},
    {class = "label"; x = 1; y = 11; height = 1; width = 1; label = 'II) by "Line start_time":';},
    {class = "label"; x = 1; y = 12; height = 1; width = 1; label = '    1-a) 01:07:25.220';},
    {class = "label"; x = 1; y = 13; height = 1; width = 1; label = '    1-b) 1:7:25.22';},
    {class = "label"; x = 1; y = 14; height = 1; width = 1; label = '    1-c) 1 7 25 22';},
    {class = "label"; x = 1; y = 15; height = 1; width = 1; label = '    1-d) 1:7.25 22';},
    {class = "label"; x = 1; y = 17; height = 1; width = 1; label = '    2-a) +1:7:25.22 -> "Find next" occurrence';},
    {class = "label"; x = 1; y = 18; height = 1; width = 1; label = '    2-b) -1:7:25.22 -> "Find previous" occurrence';}
	
}	-- of tmp_conf array

	aegisub.dialog.display(tmp_conf, {"OK"})		
end


aegisub.register_macro(script_name, script_description, goToLine)