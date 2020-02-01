script_name = "Replace text"
script_description = "Replace text as user defined"
script_author = "LORD47"
script_version = "2.9.3"

re = require 'aegisub.re'
lfs = require 'aegisub.lfs'

include("utf8.lua")

if(not dialg)then dialg = {} end
dialg.conf = {}

vars_tbl = {["global"] = {}, ["locals"] = {}}
vars_log = {log_type = '', entries = {}, undefined_vars = {global = {}, locals = {}}}

function appContext(subtitles, selected_lines, active_line)

    local items = {"1- Do not log constants values changes", "2- Log All constants values changes",
	               '3- Only log "global" constants values changes', '4- Only log "local" constants values changes'}

	local tmp_conf = {name = "log_vars"; class = "dropdown"; x = 1; y = 0; height = 1; width = 7; value = items[1]; items = items}

	local cfg_res

    repeat
	 dialg.conf = {}

     table.insert(dialg.conf, {class = "label"; label = '"Defined Constants" values changes:'; x = 0; y = 0 ; height = 1; width = 1;})
     table.insert(dialg.conf, tmp_conf)
	 
     cfg_res, config = aegisub.dialog.display(dialg.conf, {"Replace Text", "Help", "Close"} )

     if(tostring(cfg_res) ~= "false")then
	 
      if(string.lower(cfg_res) == "replace text")then
	   local tmp_val = trim(string.match(trim(config["log_vars"]), "^%d+"))
	   --aegisub.debug.out('log type = %s\nmatched = %s\n', trim(config["log_vars"]), tmp_val)-- tbr
	   
	   vars_log = {log_type = tmp_val, entries = {}, undefined_vars = {global = {}, locals = {}}}
	   
 	   replaceNames(subtitles, selected_lines, active_line)
      elseif(string.lower(cfg_res) == "help")then showHelp() end
     end

    until(tostring(cfg_res) == "false" or string.lower(cfg_res) == "replace text" or string.lower(cfg_res) == "close")
end


function replaceNames(subtitles, selected_lines, active_line)
      -- file_name = aegisub.dialog.open(title, default_file, default_dir, wildcards,
      --                                 allow_multiple=false, must_exist=true)
      local filenames = aegisub.dialog.open('Select file to read', '', '',
                                           'Text files (.txt)|*.txt', true, true)
      local needs_conf = {}
      vars_tbl = {["global"] = {}, ["locals"] = {}}

   if(filenames ~= nil)then      
    local nbRplcdWrds = 0
	local dlg_st_at = 0	
    local rules, rules_keys, rplcd_at_lines = {}, {}, {}

	 for file_idx = 1, #filenames do
      local filename = filenames[file_idx]

      if(not filename)then aegisub.debug.out("Error! Non-existing file: " .. filename .. "\n") 
	  else -- file exists
 	      --if(file_idx > 1)then aegisub.debug.out("\n")end

	      aegisub.debug.out("Loading the file: " .. filename .. "\n")

	      local file = assert(io.open(filename, 'rb'))
	      local names = file:read("*a")
	      file:close()

	      --rules = loadNames(names)
	      rules = loadNames(filename, names, rules, rules_keys)
	     end -- end of: else -- file exists
	 end

	 rules_keys = nil

     if(#rules > 0)then	 
	  local idx = 0

	  local dlg_st_at = 0

	  for i = 1, #subtitles do
	   local line = subtitles[i]

	   if(line.class == "dialogue")then
		idx = idx + 1

		if(dlg_st_at == 0)then dlg_st_at = i end
		
		local str, _, tags, tmp_nbRplcdWrds = replaceText(i, idx, rules, line.text, true, rplcd_at_lines, needs_conf, true)
		nbRplcdWrds = nbRplcdWrds + tmp_nbRplcdWrds

		if(tmp_nbRplcdWrds > 0)then		
		 line.text = tags .. str
		 subtitles[i] = line
		end

	   end

	  end

	  -- count number of replacements that need confrimation
	  local total_repls_to_review = 0
	  for _, val in pairs(needs_conf) do total_repls_to_review = total_repls_to_review + val.total_rules  end

	  if(total_repls_to_review > 0)then
       local tmp_conf
       local tmp_tbl
       local cfg_res
       local config = {}
       local txt_box_hight, txt_box_width = 4, 5
	   local nb_rows = 3
	   local cntrl_list
	   local reviewed_repls = 0

	   repeat
		 tmp_conf = {}
		 tmp_tbl = {}
		 cfg_res = ""
		 cntrl_list = {}

         local pos_y = 0
		 local current_row = 0

		  for key, val in pairs(needs_conf) do
		   local line = subtitles[key]

		   for v, rule in pairs(val.rules) do
		      reviewed_repls = reviewed_repls + 1
		      local str, old_str, tags, _ = replaceText(i, idx, {rule}, line.text, false, rplcd_at_lines, needs_conf, false)

				-- tags
				-- label
				tmp_tbl = { class = "label"; label = string.format("Tags: @Line %d:  Reviewing %d/%d replacement(s): ", ((key+1)-dlg_st_at), (val.nb_reviewed_rules + 1), val.total_rules);  x = 0; y = pos_y; height = 1; width = 1; }
				table.insert(tmp_conf, tmp_tbl)

				-- edit text
				tmp_tbl = { name = "line_tags_" .. key .. "_" .. v; class = "edit"; x = 0; y = (pos_y + 1); height = 1; width = (txt_box_width * 5);
							value = tags; hint = "Tags of the current subtitle line";
						  }
				table.insert(tmp_conf, tmp_tbl)

				-- labels
				-- wrgn_word
				tmp_tbl = { class = "label"; label = "Original: @" ..  display_time(line.start_time);  x = 0; y = (pos_y + 2); height = 1; width = 1; }
				table.insert(tmp_conf, tmp_tbl)

				-- cr_word
				tmp_tbl = { class = "label"; label = "Replacement:";  x = txt_box_width; y = (pos_y + 2); height = 1; width = 1; }
				table.insert(tmp_conf, tmp_tbl)

				-- textboxes
				-- wrgn_word
				tmp_tbl = { name = "wrgn_word_" .. key .. "_" .. v; class = "textbox"; x = 0; y = (pos_y + 3); height = txt_box_hight; width = txt_box_width;
							 value = old_str; hint = rule.hint ;
						  }
				table.insert(tmp_conf, tmp_tbl)

				-- cr_word
				tmp_tbl = { name = "cr_word_" .. key .. "_" .. v; class = "textbox"; x = txt_box_width; y = (pos_y + 3); height = txt_box_hight; width = (txt_box_width  * 4);
							 value = str; hint = rule.hint;
						  }

				table.insert(tmp_conf, tmp_tbl)

				-- confirm replace checkbox
				tmp_tbl = { name = "confirm_chkbx_" .. key .. "_" .. v; class = "checkbox"; label = "Replace";  x = 0; y = (pos_y + 3 + txt_box_hight); height = 1; width = 1; 
						   value = true}
				table.insert(tmp_conf, tmp_tbl)

				table.insert(cntrl_list, key .. "_" .. v)

			  pos_y = (pos_y + 5 + txt_box_hight)
			  current_row = current_row + 1
			  break -- to use only 1 "rule" for each reviewed "line"
			end --end of: for v, rule in pairs(val.rules) do

			if(current_row >= nb_rows) then break end

		    end -- end of : for key, val in pairs(needs_conf) do

			-- total_repls_to_review
			-- label
			tmp_tbl = { class = "label"; label = string.format("Total Replacement(s): %d/%d", reviewed_repls, total_repls_to_review);  x = 0; y = pos_y; height = 1; width = 1; }
			table.insert(tmp_conf, tmp_tbl)

			-- if no extra replacement is available to be confirmed -> exit
			if(#cntrl_list == 0)then break end

			cfg_res, config = aegisub.dialog.display(tmp_conf, {"Replace", "Skip", "Close"} )
			if(tostring(cfg_res) ~= "false" and (string.lower(cfg_res) == "replace" or string.lower(cfg_res) == "skip"))then
			 for cntrl_item_key, cntrl_item_val in pairs(cntrl_list)do

			  sub_idx , rule_idx = cntrl_item_val:match("(%d+)%_(%d+)")
			  sub_idx, rule_idx = tonumber(sub_idx), tonumber(rule_idx)

			  if(string.lower(cfg_res) == "replace")then

			   if(config["confirm_chkbx_" .. cntrl_item_val])then
			   	-- replace the confirmed text
				local line = subtitles[sub_idx]

			   	-- log stats -> must be done before the next step
				_, _, _, tmp_nbRplcdWrds = replaceText(sub_idx, ((sub_idx+1)-dlg_st_at), {needs_conf[sub_idx].rules[rule_idx]}, line.text, false, rplcd_at_lines, needs_conf, true)

                nbRplcdWrds = nbRplcdWrds + tmp_nbRplcdWrds

			    line.text = trim(config["line_tags_" .. cntrl_item_val]) .. trim(config["cr_word_" .. cntrl_item_val])
				subtitles[sub_idx] = line
			   end
			  end -- end of: if(string.lower(cfg_res) == "replace")then

			  table.remove(needs_conf[sub_idx].rules, rule_idx)

			  needs_conf[sub_idx].nb_reviewed_rules = needs_conf[sub_idx].nb_reviewed_rules + 1
			 end

			end

			until(tostring(cfg_res) == "false" or string.lower(cfg_res) == "close")
	 end -- end of: if(total_repls_to_review > 0)then

     
     for _, log_entry in pairs(vars_log.entries)do
	  aegisub.debug.out(log_entry)  
	 end

	 showStats(rplcd_at_lines)

    end -- end of: if(#rules > 0)then


    -- vars_log = {log_type = '', entries = {}, undefined_vars = {global = {'fname' = { 'line' ={vars_keys} }}, locals = {'fname' = {} }}}
    --if(#vars_log.undefined_vars > 0)then
    if(true)then
	 local nb_global_local = 0
	 local captions = {global = "Global", locals = "Local"}
	 
	 for k, filenames in pairs(vars_log.undefined_vars) do
	   aegisub.debug.out('\nvar_type = %s\n', k)
	   for fname, line_numbers in pairs(filenames)do
	    aegisub.debug.out('\nfname = %s\n', fname)
	    for line_number, var_keys in pairs(line_numbers) do
		
		 for _, a_var in pairs(var_keys) do
          nb_global_local = nb_global_local + 1		
		  aegisub.debug.out(string.format('Undefined %s constant "%s" @line: %s in file: %s\n', captions[k], a_var, tostring(line_number), fname))
		 end
		 
		end

	   end
	  
	 end
	 
	 if(nb_global_local > 0 )then
	  aegisub.debug.out('\n----------------------------------------------------------\nWarning! %d undefined Global/Local constant(s).\n', nb_global_local)
	 end

	end	

    if(#vars_log.entries > 0)then
	 aegisub.debug.out('\n----------------------------------------------------------\nWarning! %d Global/Local constant(s) were updated.\nView above for more information.\n', #vars_log.entries)
	end

    aegisub.debug.out('\nReplaced %d word(s).\n', nbRplcdWrds)
  end -- end of: if(filenames ~= nil)	
end


function removeAllComments(t)
    local new_t = {}

	for i = 1, #t do
      if((not isempty(t[i])) and (re.match(trim(t[i]), '^#.*') == nil))then
	   table.insert(new_t, {str = trim(t[i]), line = i})
	  end
    end
	
 return new_t	
end


function get_file_path(filename)
local dir, fname = filename:match('(.-)([^\\/]-%.?[^%.\\/]*)$')

 if(dir == nil)then dir = '' end
  
 return dir, fname
end

function load_file(default_file_path, fname)

    local t, set_dir, script_dir = {}, false, lfs.currentdir()
	
    local dir, filename = get_file_path(fname)
	
	local file_path = dir .. filename
	
	-- check if it's a relative path
	if(dir == '' or dir.sub(1,1) == '.')then 
      set_dir = true

	elseif(dir.sub(1,1) == '/' or dir.sub(1,1) == '\\' or dir:match('^([a-zA-Z]%:\\)') == nil)then
	 if(package.config:sub(1,1) == '\\')then  -- OS is Windows
	   set_dir = true
	 end
	end 
	
	if(set_dir)then
	 local path = get_file_path(default_file_path)
     lfs.chdir(path)
	end
	
	local file = io.open(file_path, "rb")
	
    if(file == nil)then aegisub.debug.out('Error! External file: "%s" doesn\'t exist -> ignoring this file.\n', file_path) 
	else -- file exists
	    aegisub.debug.out("Loading the external file: %s\n", file_path)

	    local file_lines = file:read("*a")
	    file:close()

	    t = split(trim(file_lines), '\n')
	    t = removeAllComments(t) -- t will be transformed from t(str, ..) to t( (str, line_number), ..)
	   end

  if(set_dir)then lfs.chdir(script_dir)end
  
 return t
end


-- parse and load "vars" from files found in "%load file_name" commands
function load_external_files(default_file_path, vars, t, idx)
   local tmp_vars, tbl = {["global"] = {}, ["locals"] = {}}, {}
   local str
   local nb_added_vars = 0
   
   local files_list, i = get_files_list(t, idx)
   
   for k = 1, #files_list do
    tbl = load_file(default_file_path, files_list[k])

	if(#tbl > 0)then
	 -- if vars_log is enabled then only log globals
	 local tmp_log_type = ''
   
	 if(vars_log.log_type == '2' or vars_log.log_type == '3')then tmp_log_type = 3 end
	 
	 vars, _, nb_added_vars = loadVars(vars, tbl, 1, {load_all_vars = true, exclude_vars = 'local', log_vars = tmp_log_type, fname = files_list[k]})
	 
	 if(nb_added_vars > 0)then
	  tmp_vars = load_external_files(default_file_path, tmp_vars, tbl, 1)
	  
	  for key, v in pairs(tmp_vars.global) do
       str = applyVars(v, tmp_vars, {fname = files_list[k]})
	   tmp_vars.global[key] = str
      end
   
	 end

	end

   end

 
  --if(nb_added_vars > 0)then
  if(nb_added_vars < 0)then -- for testing -- tbr

   for k, v in pairs(vars.global) do
    str = applyVars(v, tmp_vars)
	vars.global[k] = str
   end
  end
 
 return vars, i
end

-- parse table elements for sequential "%load file_name" command
function get_files_list(t, idx)
    if(t[idx] == nil)then return {}end

    local files_list, hash = {}, {}
	local i, last_file_cmd_id = idx, idx
	 
	pattern = '^\\%load\\s+(.+)'

	repeat

     matches = re.match(trim(t[i].str), pattern)
	 
	 if(matches ~= nil)then
       -- prevent duplicated values 
	   if(hash[trim(string.lower(matches[2].str))] == nil)then
	    table.insert(files_list, trim(string.lower(matches[2].str)))

		hash[trim(string.lower(matches[2].str))] = true
	   end

	   last_file_cmd_id = i  	   
	 end

     i = i + 1
	until(matches == nil or i > #t)

 if(#files_list > 0)then -- files were added -> push the "index" of "t" to the next position
  last_file_cmd_id = last_file_cmd_id + 1
 end
 
 return files_list, last_file_cmd_id
end



function loadNames(filename, names_list, tmp_rules, rules_keys)
      --local name, fls_names = {}, {}
	  local rules, tmp = tmp_rules, {}
      t = split(trim(names_list), '\n')

	  t = removeAllComments(t) -- t will be transformed from t(str, ..) to t( (str, line_number), ..)

	  local tmp = {}
	  local i = 1
	  local tmp_class, crnt_ln
	  local rule_class = ''
	  local hint = ''
	  local new_rule_valid = false

	  -- reset vars_tbl.locals
	  vars_tbl.locals = {}

      while(i <= #t) do
		new_rule_valid = false

        vars_tbl, i = load_external_files(filename, vars_tbl, t, i)
		
		if(i > #t)then break end
		
        vars_tbl, i = loadVars(vars_tbl, t, i, {log_vars = vars_log.log_type, fname = filename})
		--print_vars(vars_tbl)-- tbr
		
		if(i > #t)then break end
		
		_, _, tmp_class = trim(t[i].str):find('^(%%[%d]*)')

		-- %1 regex_to_check_against
		if(tmp_class ~= nil and tmp_class == '%1')then -- it's not misformed Regex (starts with a % but not with %1)
         tmp = {}
         tmp[1] = trim(string.sub(trim(t[i].str), string.len(tmp_class) + 1))
         
         -- %2 string_to_replace_with
         if(t[i+1] ~= nil and string.sub(trim(t[i+1].str), 1, 2) == '%2')then
             tmp[2] = trim(string.sub(trim(t[i+1].str), 3))
             
             
             wrng_names = applyVars(trim(tmp[1]), vars_tbl, {fname = filename, line = t[i].line})
             cr_name = applyVars(trim(tmp[2]), vars_tbl, {fname = filename, line = t[i+1].line})

             hint = trim(tmp[2]) 
             rule_class = 'regex'
             new_rule_valid = true
			 
			 i = i + 1
             
         else
         	 new_rule_valid = false	
         	 aegisub.debug.out("\nRule was ignored! Regex match with no replacement rule @Line %d:\n %s \n-----------------------------------------------------------\n", t[i].line, trim(t[i].str))
         	end
         
   		elseif(tmp_class ~= nil)then aegisub.debug.out("\nMisformed rule was ignored @Line %d:\n %s\n----------------------------------\n", t[i].line, trim(t[i].str))
   		elseif(tmp_class == nil)then
   				local tmp = split(trim(t[i].str), '+') -- Format: correct_name+false_name[(\s|\/)false_name]
   
   				if(#tmp > 1)then -- split with Arabic string return inverse index
   				--table.insert(name, trim(tmp[2])) -- crt_name
   				--table.insert(wr_names, trim(tmp[1])) -- wr_names
   
   					wrng_names = trim(tmp[1])
   					cr_name = trim(tmp[2])
   					hint = cr_name 
   					rule_class = 'normal'
   					new_rule_valid = true
   				else 
   					new_rule_valid = false
   					aegisub.debug.out("\nMisformed data ignored @Line: " .. t[i].line .. " : " .. t[i].str)
   				end
		end

	    if(new_rule_valid)then -- no error after checking current "rule"
		 -- %ask -> confirm replacement
		 local confirm = false

		 if(t[i+1] ~= nil and string.lower(string.sub(trim(t[i+1].str), 1, 4)) == '%ask')then
		  confirm = true
		  i = i + 1
		 end

		 -- %hint (description about the current "rule", if it's not available -> use the "wrng_names" as "hint"
		 if(t[i+1] ~= nil and string.lower(string.sub(trim(t[i+1].str), 1, 5)) == '%hint')then
		  -- copy the string after "%ask"
		  hint = string.lower(trim(string.sub(trim(t[i+1].str), 6)))

		   i = i + 1
		 end

		 if(rules_keys[wrng_names] == nil)then -- not duplicate rule
		  table.insert(rules, {cr_name = cr_name, wrng_names = wrng_names, class = rule_class, confirm = confirm, hint = hint})
		  rules_keys[wrng_names] = {cr_name = cr_name, class = rule_class, hint = hint, filename = filename}
		 else -- possible duplicate rule
		      aegisub.debug.out('\nWarning! Duplicate rule exists in file: %s', filename)
			  aegisub.debug.out('\nThis rule already exists in file: %s', rules_keys[wrng_names].filename)
			  aegisub.debug.out('\nThe rule is:\n %s \n %s\n This duplicate is ignored.\n', wrng_names, cr_name)

			  if(rules_keys[wrng_names].class ~= rule_class)then
			   aegisub.debug.out('Although, one is a "Regex" unlike the other.\n', rules_keys[wrng_names].filename)
			  end
		     end
	    end

	    i = i + 1				
	  end -- end of: while(i <= #t) do

 return rules
end


function confirmThis(line_idx, rule, conf_tbl, tags)
	if(conf_tbl[line_idx] == nil)then 
		 conf_tbl[line_idx] = {nb_reviewed_rules = 0, rules = {rule}}
	else
		table.insert(conf_tbl[line_idx].rules, rule)
	end

	conf_tbl[line_idx]['total_rules'] = #conf_tbl[line_idx].rules
end


function showStats(rplcd)

 for k, v in pairs(rplcd) do
  t = split(rplcd[k].lines, ' ')

  if(string.lower(trim(rplcd[k].class)) == 'regex')then
   aegisub.debug.out("\n [ %d Replacement(s) using PCRE]\n %s \n @Line(s): ", #t, rplcd[k].hint)
  else aegisub.debug.out("\n[ %d Replacement(s) ]\n %s \n @Line(s): ", #t, rplcd[k].hint) end

  for i = 1, #t do
   if(i == 1)then -- initialize
    current_line = tonumber(t[i])
    int_start, int_end, all_done = tonumber(t[i]), tonumber(t[i]), false

   elseif(tonumber(t[i]) == current_line + 1)then int_end, current_line = tonumber(t[i]), tonumber(t[i]) -- sequence
   else if(int_end == int_start)then
	     aegisub.debug.out("%d ", int_start)
         all_done = true

         elseif(int_end > int_start)then
	     aegisub.debug.out("%d-%d ", int_start, int_end)
 	     all_done = true
 	    end -- end of: if(int_end == int_start)

        -- initialize with the new infos
        current_line = tonumber(t[i])
        int_start, int_end, all_done = tonumber(t[i]), tonumber(t[i]), false
   end -- end of: if(i = 1)
  end -- end of: for i = 1, #t do

  -- last line wasn't added
  if(not all_done)then
   if(int_end == int_start)then aegisub.debug.out("%d ", int_start)
   elseif(int_end > int_start)then  aegisub.debug.out("%d-%d ", int_start, int_end) end
  end

  aegisub.debug.out("\n-----------------------------------------------------------------------------")
 end
end


function replaceText(i, idx, rules, line_txt, check_confirm, rplcd_at_lines, needs_conf, log_stats)
		local nbRplcdWrds = 0
	    local tags, s = line_txt:match("(%{[^}]+%})(.+)")

	    if(tags == nil)then
 	     tags = ""
	     s = line_txt
	    elseif(s == nil)then s = "" end

		local str = s
		local original_str = str
		local old_str

	    for j = 1, #rules do
		 local nbRep
		 old_str = str

		 if(rules[j].class == 'regex')then	-- "regex" replacement
		  if(re.match(str, rules[j].wrng_names) ~= nil)then -- rule pattern matched	
		   if(check_confirm and rules[j].confirm == true)then -- text replace needs confirmation
			confirmThis(i, rules[j], needs_conf, tags)
		   else -- text replace does not need confirmation
			   str = re.sub(str, rules[j].wrng_names, rules[j].cr_name)
			   nbRplcdWrds = nbRplcdWrds + 1

			   if(log_stats)then
			    if(rplcd_at_lines[rules[j].wrng_names] ~= nil) then rplcd_at_lines[rules[j].wrng_names].lines = rplcd_at_lines[rules[j].wrng_names].lines .. ' ' .. idx
			    else rplcd_at_lines[rules[j].wrng_names] = {lines = idx, cr_name = rules[j].cr_name, class = rules[j].class, hint = rules[j].hint} end
			   end
		   end

		  end

		 else -- "normal" replacement
			 pos, _ = string.find(trim(rules[j].wrng_names), '%/') -- check if split is by "/" -> we're replacing multiple words
			 local tmp = {}

			 if(pos ~= nil)then tmp = split(trim(rules[j].wrng_names), '/')
			 else tmp = split(trim(rules[j].wrng_names), ' ') end

			 if(#tmp == 0)then aegisub.debug.out("\n %s @Line %d", "Invalid dictionnairy string to split", j) end

			 for k = 1, #tmp do
			  if( not isempty(tmp[k]) )then
			   nbRep = 0
			   str, nbRep = string.gsub(str, '%' .. trim(tmp[k]), rules[j].cr_name)
			   str, _ = string.gsub(str, "%&%&", ' ') -- replace $$ after a word with a space -> because Trim in a rule eliminates both "spaces" at rigt and left

			   if(nbRep ~= nil and nbRep > 0)then -- str has been changed

				if(check_confirm and rules[j].confirm == true)then -- text replace needs confirmation
				 confirmThis(i, rules[j], needs_conf, tags)
				 str = old_str
				else -- text replace does not need confirmation
					nbRplcdWrds = nbRplcdWrds + 1

					if(log_stats)then	
					 if(rplcd_at_lines[ tmp[k] ] ~= nil) then  rplcd_at_lines[ tmp[k] ].lines = rplcd_at_lines[ tmp[k] ].lines .. ' ' .. idx
					 else rplcd_at_lines[ tmp[k] ] = {lines = idx, cr_name = rules[j].cr_name, class = rules[j].class, hint = rules[j].hint} end
					end
				end

			   end
			  end -- end of: if( not isempty(tmp[k]) )then
			 end -- end of: for k = 1, #tmp do
		 end -- end of: if(rules[j].class == 'regex')then
		end -- end of: for j = 1, #rules do

  return str, original_str, tags, nbRplcdWrds, rplcd_at_lines
end



function loadVars(vars, t, idx, options)
    local vars_tmp = vars
	local i, lest_var_id = idx, idx
	local nb_added_vars = 0
	-- log_vars {1-> don't log, 2->log all, 3->globals only, 4->locals only}
	local vars_defaults = {load_all_vars = false, exclude_vars = '', log_vars = '', fname = 'undefined'}
	local options = options or vars_defaults
	
	
	-- init missing key+value
	options = set_defaults(options, vars_defaults)
     
    -- global vars start with "_"
	pattern = '^\\%\\$[_]([a-zA-Z][a-zA-Z\\_0-9]*)\\s*=\\s*(.+)'

	repeat

     matches = re.match(trim(t[i].str), pattern)
	 
	 if(matches ~= nil )then
	   if(trim(string.lower(options.exclude_vars)) ~= 'global')then
	    local var_key = trim(string.lower(matches[2].str))

		if(vars_tmp.global[var_key] and (options.log_vars == '2' or options.log_vars == '3'))then
		  local log_entry = string.format('Global constant "%s" was set @line: %d in file: %s,\nFrom: %s\nTo: %s\n\n',
  		                                   var_key, t[i].line, options.fname, vars_tmp.global[var_key], trim(matches[3].str))

		  table.insert(vars_log.entries, log_entry)
		end
		
	    vars_tmp.global[string.lower(matches[2].str)] = trim(matches[3].str)
		nb_added_vars = nb_added_vars + 1
	   end
		
	   lest_var_id = i + 1
	   
	   else
	    pattern2 = '^\\%\\$([a-zA-Z][a-zA-Z\\_0-9]*)\\s*=\\s*(.+)'
	    matches = re.match(trim(t[i].str), pattern2)
		
		if(matches ~= nil)then
		 if(trim(string.lower(options.exclude_vars)) ~= 'local')then
          local var_key = trim(string.lower(matches[2].str))
          
          if(vars_tmp.locals[var_key] and (options.log_vars == '2' or options.log_vars == '4'))then
            local log_entry = string.format('Local constant "%s" was set @line: %d in file: %s,\nFrom: %s\nTo: %s\n\n',
  		                                   var_key, t[i].line, options.fname, vars_tmp.locals[var_key], trim(matches[3].str))
          
            table.insert(vars_log.entries, log_entry)
          end
		
	      vars_tmp.locals[string.lower(matches[2].str)] = trim(matches[3].str)
		  nb_added_vars = nb_added_vars + 1
		 end
		 
		 lest_var_id = i + 1
        end	  
	   	   
	 end

     i = i + 1
	until( (matches == nil and options.load_all_vars ~= nil and not options.load_all_vars) or i > #t)

	
 return vars_tmp, lest_var_id, nb_added_vars
end


function applyVars(val, vars, options)
    local str = val
	local tmp_str = ''
	
	local vars_defaults = {fname = 'n/a', line = 'n/a'}
	local options = options or vars_defaults
		
	-- init missing key+value
	options = set_defaults(options, vars_defaults)

	pattern  = '\\%(_?[a-zA-Z][a-zA-Z_0-9]*)\\%'		
	
	repeat
	 matches = re.match(str, pattern)
	 
	 local isGlobal, apply = false, false
	 
	 if(matches ~= nil)then   
	   isGlobal = (string.utf8sub(matches[2].str, 1, 1) == '_')
	   
	   local key_global = string.lower(string.utf8sub(matches[2].str, 2, -1))
	   local key_local = string.lower(matches[2].str)
	   
	   apply = (isGlobal and vars.global[key_global] ~= nil) or (not isGlobal and vars.locals[key_local] ~= nil)
	   
	   if(apply)then
	    if(isGlobal)then str = re.sub(str, matches[1].str, vars.global[key_global])
	    else str = re.sub(str, matches[1].str, vars.locals[key_local])end
		
	   else -- test the rest of the non-matched sub-string
	        
		   -- log the missing constant
		   if(isGlobal)then

		    if(vars_log.undefined_vars.global[options.fname] == nil)then
			 vars_log.undefined_vars.global[options.fname] =  {}
			 vars_log.undefined_vars.global[options.fname][options.line] = {}
			 table.insert(vars_log.undefined_vars.global[options.fname][options.line], key_global)

            elseif(vars_log.undefined_vars.global[options.fname][options.line] == nil)then
              vars_log.undefined_vars.global[options.fname][options.line] = {key_global}

			elseif(not value_exists(vars_log.undefined_vars.global[options.fname][options.line], key_global))then	   
			       table.insert(vars_log.undefined_vars.global[options.fname][options.line], key_global)
			     end

		   else
               --if(vars_log.undefined_vars[		   
		        --table.insert(vars_log.undefined_vars, string.format('Missing local constant "%s"\n', key_local))
			   end

		   
		   -- tmp_str = str:utf8sub(1, matches[1].last)
           -- utf8sub could not work correctly if used with a non-ASCII string		   
		   -- it uses str:sub(first_byte, last_byte) that somehow treats 2 bytes as if they are 1 byte
		   -- for example this string: str = م%a_var%x (م is 2 bytes) 
		   -- and the result of: str:utf8sub(1, matches[1].last) as str:utf8sub(1, 9)
		   -- will produce م%a_var%x rather than م%a_var%

		   tmp_pattern = '^(.*?\\%_?[a-zA-Z][a-zA-Z_0-9]*\\%)(.*)$'
		   tmp_str_matches = re.match(str, tmp_pattern)
		   
		   if(tmp_str_matches ~= nil)then
		    tmp_str = tmp_str .. tmp_str_matches[2].str
			str = tmp_str_matches[3].str
		   end

	   end
	   	   	   
     end

	until(matches == nil)
	
 return (tmp_str .. str)
end



-- show help
function showHelp()
     local tmp_conf = {}
	 local help_str = 'This scirpt reads rules from text files to match and replace expressions, there are 2 ways to do so:' .. 
                      '\n1-Via "Regular Expression (regex)" (see "re" module of aegisub for more informations) using the following method:\n  %1 regex_match_expression\n  %2 regex_replace_expression' ..
                      "\n\n  Example: subtitle line text = they should of...\n  %1 (should|could)\\s+of \n  %2 \\1've\n  after applying the above rule, the replaced text would be:   they should've..." ..
			          '\n\n2-Via "Simple Match":  match_expression+replace_expression with 2 cases:'	.. 
                      '\n  a-match_expression contains no spaces' ..
                      '\n    Example: subtitle line text = wich is wrong...\n    wich+which\n    after applying the above rule, the replaced text would be:   which is wrong...' ..
					  '\n\n  b-match_expression contains spaces' ..
                      "\n    Suppose we have the following rules:\n     Rule1:\n                /aren't/'re not+are not\n                Example1: they aren't here. -> they are not here.\n                Example2: they're not here. -> theyare not here." ..
					  "\n     Rule2:\n                /should have+should've\n                Example: you should have seen it. -> you should've seen it." ..
					  '\n\nImportant remarks:    (for both "regex" and "Simple Match" case)'	..
					  '\n  1-you can add "%ask" after the replace_expression  to "confirm" (and possibly edit) the replacement text.' ..
					  '\n\n  2-if you add "%hint rule_description" after the replace_expression (and after %ask expression if it exists), the "rule_description"' ..
					  '\n     will be used as a description text in the replacements log dialog for the rule applied (otherwise the replace_expression is used).' ..
					  '\n\n  3-Lines that start with # are treated as comments and thus ignored (so is for empty lines).'

     -- GUI
     tmp_conf = { {class = "label"; x = 0; y = 0; height = 1; width = 1; label = help_str; } }

	aegisub.dialog.display(tmp_conf, {"OK"})
end


-- split a string on a delimiter
function split (s, delim)

  assert(type(delim) == "string" and string.len (delim) > 0,"bad delimiter")

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


function isempty(s)
 return (s == nil or trim(s) == '')
end


function display_time(mseconds)
  local seconds = tonumber(mseconds)/1000
  local mscs = tonumber(mseconds) % 1000
  

  if(seconds <= 0) then return "00:00:00." .. mscs;
  else
    hours = string.format("%02.f", math.floor(seconds/3600));
    mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
    secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));
    return hours .. ":" .. mins .. ":" .. secs .. "." .. mscs
  end
end




function set_defaults(tbl, vals)
   for k, v in pairs(vals)do
    if(tbl[k] == nil)then
	 tbl[k] = v
	end 
   end
   
 return tbl
end


function value_exists(t, element)
  for _, value in pairs(t) do
    if(trim(string.lower(value)) == trim(string.lower(element))) then
      return true
    end
  end
  return false
end

-- tbr
function print_vars(vars)
  for k, v in pairs(vars.global) do
   aegisub.debug.out('%s = %s\n', k, v);
  end
end

aegisub.register_macro(script_name, script_description, appContext)
