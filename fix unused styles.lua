script_name = "Fix styles"
script_description = "Find all non-declared/unused styles"
script_author = "LORD47"
script_version = "1.0"

if not dialg then dialg = {} end

dialg.conf = {}

function fixStyles(subtitles, selected_lines, active_line)
    local tmp_avail = {}
    local tmp_used = {}
	local unused_undec = {}
	local used_styles = {}
	local avail_styles = {}
	local tmp_tbl ={}	
	local cfg_res
	local config = {}
	local dlgbtns = {}
	local act_type = "1- All the non-declared styles"
	local dflt_str
	
repeat	
	
	dialg.conf = {}
	
	-----
	tmp_tbl = { class = "label"; label = "Find all:" ;
 	            x = 0; y = 0 ; height = 1; width = 1; }				 
    table.insert(dialg.conf, tmp_tbl )
	  
----------- dropdown menu to choose the source of the styles from --------------------
	
 	tmp_tbl = { name = "act_type"; class = "dropdown"; x = 1; y = 0; height = 1; width = 7; value = act_type;	          
			    items = {"1- All the non-declared styles" , '2- All the unused styles'} 
			  }
     
    table.insert(dialg.conf, tmp_tbl )
	
	dlgbtns = {"Next", "Close"}
	cfg_res, config = aegisub.dialog.display(dialg.conf, dlgbtns)	
	

----------- user clicked on a button from the previous menu ----------------------------
	
  if(tostring(cfg_res) == "false" )then -- user closed the window
   aegisub.debug.out("\nCanceled.\n")
   aegisub.cancel()
  elseif(string.lower(cfg_res) == "next")then -- continue 
  
	act_type = config["act_type"]
	local s = string.match(act_type, "%d+")
	
	aegisub.debug.out("Find all : " .. act_type .. "\n")
	
	----------
	
	-- collect styles from [Styles] section and also from "dialogues"
	-- avail_style[style_name], used_style[style_name] = subtitle_Line_idx ,  tmp_avail[1] = style_name
	avail_styles, tmp_avail = collect_styles_av(subtitles)
	used_styles, tmp_used = collect_styles_assumed(subtitles)
	
	-- unused_undec[1] = style_name
	if(s == "1") then  -- non-declared styles
	 unused_undec = missing_styles(tmp_used, avail_styles)
 	elseif(s == "2")then -- unused styles
 	 unused_undec = missing_styles(tmp_avail, used_styles)
    end
	
	aegisub.debug.out("Verify styles done.\n") 
	
	local idx = #unused_undec	

  repeat		-- 2nd menu
    -- a dialog display	
	if(s == "1") then  -- non-declared styles
	 dialg.conf, dlgbtns = show_another_Dialog(unused_undec, tmp_avail, s, config)
	 
	elseif(s == "2")then -- unused styles 	 
	 local suggest = missing_styles(tmp_used, avail_styles)
	 dialg.conf, dlgbtns = show_another_Dialog(unused_undec, suggest, s, config)
	end
		
	cfg_res, config = aegisub.dialog.display(dialg.conf, dlgbtns)
		
		
	if(tostring(cfg_res) == "false" )then -- user closed the window
	 aegisub.debug.out("\nCanceled.\n")
	 aegisub.cancel()
    elseif( string.lower(cfg_res) == "select all")then sellect_all_none(config, "n", "stl_ckbx_", idx, true)
	elseif( string.lower(cfg_res) == "select none")then sellect_all_none(config, "n", "stl_ckbx_", idx, false)
	elseif( string.lower(cfg_res) == "reverse selection")then sellect_all_none(config, "r", "stl_ckbx_", idx, false)
	elseif( string.lower(cfg_res) == "rename selected") then
	
	 local rep_style = {}
	 
	 -- collect the selected styles
	 local j = 0
	 local tmp_rep_style, interval_style = {}, {}
	 
	 for i=1, idx do	  
	  if(config["stl_ckbx_" .. i])then	   
	   table.insert(tmp_rep_style, unused_undec[i])
	   rep_style[ unused_undec[i] ] = trim(config["stl_new_" .. i])
	   interval_style[ unused_undec[i] ] = ' '
	   j = j +1
	  end
     end	 
	 
	 	 
	 -- I'm here
	
	 if(j > 0 )then   -- j > 0 -> there's at least a selected style to be replaced with a new valid one 	  
	  
	  if(s == "1")then -- rename non-declared styles
	   local ln, int_start, int_end, all_done = 0, 0, 0, false
	   local current_style = 'wbxxnoneyys'
	  
	   for i = 1, #subtitles do
        local line = subtitles[i]
	    aegisub.progress.set( (i*100) / #subtitles )	    
		
        if(line.class == "dialogue") then
		 ln = ln + 1
		 
         if(rep_style[line.style]) then
		  --aegisub.debug.out("Line " .. ln .. ": " .. line.style .. " -> " .. rep_style[line.style] .. "\n")
		  
          ----------------------------------------		  
           if(current_style == 'wbxxnoneyys')then -- initialize
		    current_style = line.style
		    int_start, int_end, all_done = ln, ln, false
		   
		   elseif(current_style == line.style)then int_end = ln -- sequence 
		   else -- a different style
		       if(int_end > 0)then
			    if(int_end == int_start)then
 			     interval_style[current_style] = interval_style[current_style] .. int_start .. ', '
                 all_done = true				 
			    elseif(int_end > int_start)then
			     interval_style[current_style] = interval_style[current_style] .. int_start .. '-' .. int_end .. ', '
				 all_done = true
				 
				end -- end of: if(int_end == int_start)
			  
               else interval_style[current_style] = interval_style[current_style] .. int_start .. ', '
			        all_done = true
			   end -- end of: if(int_end > 0)
			  
			   -- initialize with the new style infos
			   current_style = line.style
		       int_start, int_end, all_done = ln, ln, false
			   
		   end -- end of: if(current_style == 'wbxxnoneyys')		   
		  ------------------------------------------		  
		  
		  
	      line.style = rep_style[line.style]		  		  		  
		  
		  subtitles[i] = line
         elseif(current_style ~= 'wbxxnoneyys')then
          if(int_end > 0)then
			    if(int_end == int_start)then
 			     interval_style[current_style] = interval_style[current_style] .. int_start .. ', '
			    elseif(int_end > int_start)then
			     interval_style[current_style] = interval_style[current_style] .. int_start .. '-' .. int_end .. ', '				 
				end -- end of: if(int_end == int_start)
			  
               else interval_style[current_style] = interval_style[current_style] .. int_start .. ', '
			   end -- end of: if(int_end > 0)
			  
			   -- initialize with the new style infos
			   current_style = 'wbxxnoneyys'
		       int_start, int_end, all_done = 0, 0, false		 
		  
	     end -- end of: if(rep_style[line.style]) then		 
        end -- end of: if(line.class == "dialogue") then
       end -- end: for i = 1, #subtitles
	   
	   
	   -- last style info was not added
	   if(not all_done and current_style ~= 'wbxxnoneyys')then 
	    if(int_end > 0)then
		 if(int_end == int_start)then
 		  interval_style[current_style] = interval_style[current_style] .. int_start .. ', '
		  
		 elseif(int_end > int_start)then
		  interval_style[current_style] = interval_style[current_style] .. int_start .. '-' .. int_end .. ', '
 		 end
			  
         else interval_style[current_style] = interval_style[current_style] .. int_start .. ', '
		end -- end of: if(int_end > 0)
	    
	   end
	   -------
	   
	   for key, val in pairs(interval_style) do
	    aegisub.debug.out(key .. ' -> ' ..  rep_style[key] .. ' : ' .. val .. '\n')
	   end
	  
      elseif(s == "2") then -- rename unused styles	   
	   local tmp_left = {}
	   local rmv_left = false
	   
	   -- verify if user chose to delete styles left without a new name
       if(config["rmv_left"] ~= nil) then rmv_left = config["rmv_left"] end
	   
	   -- rep_style[current_style_name] = v where v = new_style_name_to_apply
	   -- current_style_name has no duplicates here unlike v, and v should be used only once
	   local already_used = {}
	   local prgs = 0
	   
	   for i=1, #tmp_rep_style do	    
	    v = rep_style[ tmp_rep_style[i] ]
		
	    if(already_used[v] == nil)then -- means that value of v doesn't exist in table & it hasn't been used yet
		 local ndx = avail_styles[ tmp_rep_style[i] ]
	     local line = subtitles[ndx]
		 
		 aegisub.debug.out("Style: "  .. line.name ..  " -> " .. v .. "\n")
		 
	     line.name = v
	     subtitles[ndx] = line
		 already_used[v] = ndx -- register the value of v to ensure that this value is used only once

        elseif(rmv_left)then
         table.insert(tmp_left, tmp_rep_style[i] )
		end 
		
		prgs = prgs +1
		aegisub.progress.set( (prgs*100) / j )		 
	   end -- end: for i=1, #tmp_rep_style
	   
------ delete styles left without a new name ( if it's enabled & also there's something to delete ) -----------
	   if(rmv_left and #tmp_left > 0)then
	    -- display confirmation dialog
		local tmp_conf = {}
		
		local lbls ={"style:", "is", "it", "styles:", "are", "them"}
		
		local r
		if(#tmp_left < 2)then r = 0	else r = ( #lbls / 2 ) end
						
        tmp_tbl = { class = "label"; label = "The following " .. lbls[r+1] ;
 		            x = 0; y = 0 ; height = 1; width = 1; }				 
        table.insert(tmp_conf, tmp_tbl )
		
		tmp_tbl = { name = "delt_stls"; class = "dropdown"; x = 1; y = 0; height = 1; width = 1;	          
			        items = tmp_left;  value = tmp_left[1] }
				 
        table.insert(tmp_conf, tmp_tbl )
		
		tmp_tbl = { class = "label"; label = lbls[r+2] .. " left without a new name,";
 		            x = 2; y = 0 ; height = 1; width = 1; }				 
        table.insert(tmp_conf, tmp_tbl )
		
		tmp_tbl = { class = "label"; label = "Do you want to remove " .. lbls[r+3] .. "?";
    		        x = 0; y = 1 ; height = 1; width = 1; }				 
        table.insert(tmp_conf, tmp_tbl )
		
		local cfrm
		local tmp_cfg = {}
		cfrm, tmp_cfg = aegisub.dialog.display(tmp_conf, {"Yes", "No"})
		
		-- user didn't close the window & pressed "yes"
		if( tostring(cfrm) ~= "false" and string.lower(cfrm) == "yes" )then
	     for i=#tmp_left, 1, -1 do	    
	      local ndx = avail_styles[ tmp_left[i] ]	    		 
	      subtitles.delete(ndx)
		
	      aegisub.debug.out("Style: "  .. tmp_left[i] .. " -> was removed.\n")			    	    
	     end
	    end		
		
	   end	
------- end of dialog------------------------------------------------------------------------------------------	   
  	   
	  end

	  aegisub.debug.out("Styles replacing is done! Click close to view the changes.\n")
	  aegisub.debug.out("----------------------------------------------------------\n")
	 
	  aegisub.set_undo_point("Fix styles")
	 end
	 
	elseif( string.lower(cfg_res) == "remove selected" and s =="2" ) then 
	 -- collect the selected styles
	 local j = 0
	 local tmp_rep_style = {}
	 
	 for i=1, idx do	  
	  if(config["stl_ckbx_" .. i])then	   
	   table.insert(tmp_rep_style, unused_undec[i] )
	   j = j +1
	  end
     end
	 
	 -- delete the selected styles
	 if(j > 0)then
	  local prgs = 0

	  for i=#tmp_rep_style, 1, -1 do	    
	   local ndx = avail_styles[ tmp_rep_style[i] ]	    		 
	   subtitles.delete(ndx)
		
	   aegisub.debug.out("Style: "  .. tmp_rep_style[i] .. " -> was removed.\n")		
	   prgs = prgs +1
	   aegisub.progress.set( (prgs*100) / j )		 
	  end
	  
	  aegisub.debug.out("----------------------------------------------------------\n")
	 
	  aegisub.set_undo_point("Fix styles")
	 end 
	 	 
	else end
	
	
  until (string.lower(cfg_res) == "close" or string.lower(cfg_res) == "back"
         or string.lower(cfg_res) == "rename selected" or string.lower(cfg_res) == "remove selected" )

 end -- end of : if(string.lower(cfg_res) == "next")then 
 
 
until (string.lower(cfg_res) == "close")
 

end



-- prepare config
function show_another_Dialog(styles, replace_with, act_type, conf)
     local tmp_conf = {}
	 local tmp_tbl = {}	
	 local tmp_v
	 local tmp_title = ""
	 local btns ={}	 
 
	
if(#styles == 0)then -- no unused/non-declared style(s) found
 btns = {"Back", "Close"}

 if(act_type == "1")then  tmp_title = "There are no non-declared styles."
 elseif(act_type == "2")then tmp_title = "There are no unused styles." end 

 tmp_tbl = { class = "label"; label = tmp_title; x = 0; y = 0 ; height = 1; width = 1; }				 
 table.insert(tmp_conf, tmp_tbl)
 

else	

   -- shared buttons for all cases
   btns = {"Select All", "Select none", "Reverse selection"}

   if(act_type == "1")then
    tmp_title = "The non-declared styles are:"
	table.insert(btns, "Rename selected")
	
   elseif(act_type == "2")then
    tmp_title = "The unused styles are:"
	
	if(#replace_with > 0)then table.insert(btns, "Rename selected") end
	
	table.insert(btns, "Remove selected")
   end 
	
    --
	tmp_tbl = { class = "label"; label = tmp_title; x = 0; y = 0 ; height = 1; width = 1; }				 
    table.insert(tmp_conf, tmp_tbl)
	
	local pos = 1
	
	for i=1, #styles do	  -- "stl_new_" .. i
     -- checkbox to confirm change of the found style 	 
	 if(conf["stl_ckbx_" .. i] ~= nil) then tmp_v = conf["stl_ckbx_" .. i]
	 else tmp_v = true end
	 
	 tmp_tbl = { name = "stl_ckbx_" .. i ; class = "checkbox"; label = i .. "- ".. styles[i] ; 
   	             value = tmp_v; x = 0; y = i ; height = 1; width = 1 }				 
				 
     table.insert(tmp_conf, tmp_tbl )
	 
	 -- dropdown menue choose a new style name from
	 if(#replace_with > 0)then
	  tmp_tbl = { name = "stl_new_" .. i ; class = "dropdown"; x = 1; y = i ; height = 1; width = 1;
 	              items = replace_with; value = replace_with[1] }
     
      table.insert(tmp_conf, tmp_tbl )
	 end
	 
	 pos = pos + 1
    end
	
	-- 
	if(act_type == "2" and #replace_with > 0)then
 	 tmp_tbl = { class = "label"; x = 0; y = (pos+1) ; height = 1; width = 1;
	             label = "Note: Each replacing style name is used only once!"
 	           }				 
     table.insert(tmp_conf, tmp_tbl)	 
	 
	 tmp_tbl = { class = "label"; x = 0; y = (pos+2) ; height = 1; width = 1;
	             label = "          Duplicates are ignored."
 	           }				 
     table.insert(tmp_conf, tmp_tbl)	 
	 
	 -- checkbox to confirm removing of unchanged styles
	 if(#styles > #replace_with )then
	  if(conf["rmv_left"] ~= nil) then tmp_v = conf["rmv_left"]
	  else tmp_v = false end
	  
	  tmp_tbl = { name = "rmv_left" ; class = "checkbox"; x = 0; y = (pos+3) ; height = 1; width = 1;
	              value = tmp_v; label = "Remove styles left without a new name" }
				 
      table.insert(tmp_conf, tmp_tbl )
	 end
    end
	
table.insert(btns, "Back")
table.insert(btns, "Close")	
end	


return tmp_conf, btns
	
end



-- scan & collect styles that are declared on [Styles] header
function collect_styles_av(subtitles)
    local used_styles = {}
	local tmp = {}
	local str =""
	  
    for i = 1, #subtitles do
	 local line = subtitles[i]	  
     if(line.class == "style") then
	  used_styles[line.name] = i	
      table.insert(tmp,	line.name)
	  if(str == "") then str = line.name else str = str .. ", " .. line.name end
     end
    end
	
 return used_styles, tmp, str
end


-- scan & collect styles that are declared on [Styles] header
function collect_styles_assumed(subtitles)
    local used_styles = {}
	local tmp = {}
	local str =""
	  
    for i = 1, #subtitles do
	 local line = subtitles[i]	  
     if(line.class == "dialogue") then
      if(used_styles[line.style] == nil) then
 	   used_styles[line.style] = i
	   table.insert(tmp, line.style)
	   if(str == "") then str = line.style else str = str .. ", " .. line.style end
      end	  
     end
    end
	
 return used_styles, tmp, str
end


-- missing items from t1 in t2
function missing_styles(t1, t2)
     local tmp = {}
	 
     for i=1, #t1 do
	  if(t2[ t1[i] ] == nil) then table.insert(tmp, t1[i]) end
	 end
	 
 return tmp	 
end	 



-- update all checkbox state accroding to "st"
function sellect_all_none(conf, mode, name, nb, st)
 for i = 1, nb do
  if(string.lower(mode) == "n") then conf[name .. i] = st
  elseif(string.lower(mode) == "r") then conf[name .. i] = not(conf[name .. i]) end
 end
end

aegisub.register_macro(script_name, script_description, fixStyles)


-------------------------  string manipulation ------------------
-- split a string on a delimiter
function split (s, delim)

  assert (type (delim) == "string" and string.len (delim) > 0,
          "bad delimiter")

  local start = 1
  local t = {}  -- results table

  -- find each instance of a string followed by the delimiter

  while true do
    local pos = string.find (s, delim, start, true) -- plain find

    if not pos then
      break
    end

    table.insert (t, string.sub (s, start, pos - 1))
    start = pos + string.len (delim)
  end -- while

  -- insert final one (after last delimiter)

  table.insert (t, string.sub (s, start))

  return t
 
end


-- trim strng (whitespaces) on left & right
function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

