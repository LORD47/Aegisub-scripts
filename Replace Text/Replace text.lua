script_name = "Replace text"
script_description = "Replace text as user defined"
script_author = "LORD47"
script_version = "3.1"

re = require 'aegisub.re'
lfs = require 'aegisub.lfs'
util = require 'aegisub.util'

include("utf8.lua")

if(not dialg)then dialg = {} end
dialg.conf = {}

vars_tbl = {global = {}, locals = {}}
vars_log = {log_type = '', entries = {}, undefined_vars = {global = {}, locals = {}}}
invalid_commands = {}

expr_update_log = {}

default_file_path = ''

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
	   
	   vars_log = {log_type = tmp_val, entries = {}, undefined_vars = {global = {}, locals = {}}}
	   invalid_commands = {}
	   
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
      --vars_tbl = {["global"] = {}, ["locals"] = {}}
	  vars_tbl = {global = {}, locals = {}}
	  expr_update_log = {}
      default_file_path = ''

   if(filenames ~= nil)then      
    local nbRplcdWrds = 0
	local dlg_st_at = 0	
    local rules, rules_keys, rplcd_at_lines = {}, {}, {}

	 for file_idx = 1, #filenames do
      local filename = filenames[file_idx]

      if(not filename)then aegisub.debug.out("Error! Non-existing file: " .. filename .. "\n") 
	  else -- file exists
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

	  -- count number of replacements that need confirmation
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
		       local str, old_str, tags, _ = replaceText(key, idx, {rule}, line.text, false, rplcd_at_lines, needs_conf, false)

				-- tags
				-- label
				tmp_tbl = { class = "label"; label = string.format("Tags: @Line %d:  Reviewing %d/%d replacement(s): ", ((key + 1) - dlg_st_at), (val.nb_reviewed_rules + 1), val.total_rules);  x = 0; y = pos_y; height = 1; width = 1; }
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
				   local sub_idx , rule_idx = cntrl_item_val:match("(%d+)%_(%d+)")
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

	 showStats(rplcd_at_lines)

    end -- end of: if(#rules > 0)then
--print_vars(vars_tbl) -- tbr
    -- print Undefined Local/Global vars
    -- vars_log = {log_type = '', entries = {}, undefined_vars = {global = {'fname' = { 'line' ={vars_keys = expression_update_id} }}, locals = {'fname' = {} }}}
	 local nb_global_local = 0
	 local captions = {global = "Global", locals = "Local"}
	 local var_title_printed = {global = false, locals = false}
	 
	 for k, filenames in pairs(vars_log.undefined_vars) do

	   for fname, line_numbers in pairs(filenames)do

	    for line_number, var_keys in spairs(line_numbers) do
		
		 for a_var, expre_updt_id in pairs(var_keys) do
		  local var_name_prfx = trim(k):lower() == 'global' and '_' or ''
          nb_global_local = nb_global_local + 1

          if(not var_title_printed[k])then
		   	aegisub.debug.out('\n-----------------------[Undefined %s constant(s)]-----------------------\n', captions[k])
			var_title_printed[k] = true
		  end

		  aegisub.debug.out(string.format('"%s" @line: %s in file: %s\n', var_name_prfx .. a_var, tostring(line_number), fname))
		  
		  if(expre_updt_id > 0)then
		   local output_prfx_frst = 'in expression'
		   local output_prfx_rest = '                 -->'
		   aegisub.debug.out(output_prfx_frst)
						   
		   for updt_id = 1, expre_updt_id do
		    local log_update_str = fields_lookup(expr_update_log, {fname, 'lines', line_number, updt_id})

            if(log_update_str ~= nil)then
		      local ln_sfx = updt_id ~= 1 and output_prfx_rest or ''
			  local ln_prfx = updt_id == expre_updt_id and '\n\n' or '\n'

		      aegisub.debug.out('%s: %s%s', ln_sfx, tostring(log_update_str), ln_prfx)
			end

		   end
		    
		  end

		 end
		 
		end

	   end
	  
	 end
	 
	 
	 if(nb_global_local > 0)then
	  aegisub.debug.out('----------------------------------------------------------\nWarning! %d undefined Global/Local constant(s).\n', nb_global_local)
	 end



    -- print updated Local/Global vars
    if(#vars_log.entries > 0)then
	 aegisub.debug.out('\n-----------------------[%s updated Local/Global constant(s)]-----------------------\n', #vars_log.entries)

     for _, log_entry in ipairs(vars_log.entries)do	  
	  aegisub.debug.out(log_entry)
	 end
	end


    -- print errors
	if(#invalid_commands > 0)then
	 aegisub.debug.out('\n-----------------------[%s invalid command(s) found]-----------------------\n', #invalid_commands)

     for _, an_error in ipairs(invalid_commands)do	  
	  aegisub.debug.out(an_error .. "\n")
	 end
	end

    aegisub.debug.out('\n----------------------------------------------------------\nReplaced %d word(s).\n', nbRplcdWrds)
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
function load_external_files(filename, vars)
   local tmp_vars, tbl = {["global"] = {}, ["locals"] = {}}, {}
   local nb_added_vars = 0 
  
   tbl = load_file(default_file_path, filename)
   
   if(#tbl > 0)then
    -- if vars_log is enabled then only log globals
    local tmp_log_type = ''
   
    if(vars_log.log_type == '2' or vars_log.log_type == '3')then tmp_log_type = 3 end
    
    tmp_vars, _, nb_added_vars = loadVars(vars, tbl, 1, {load_all_vars = true, exclude_vars = 'local', log_vars = tmp_log_type, fname = filename})
   end
  
 return tmp_vars, i
end

-- parse table elements for sequential "%load file_name" command
function get_files_list(t, idx)
    if(t[idx] == nil)then return {}end

    local files_list, hash = {}, {}
	local i, last_file_cmd_id = idx, idx
	 
	local pattern = '^\\%load\\s+(.+)'

	repeat

     local matches = re.match(trim(t[i].str), pattern)
	 
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


function get_command_type(str)
  local arr_cmd_types = {'load_file', 'global_var', 'local_var', 'regex_match', 'regex_replace', 'hint', 'check'}
  local cmds = { {pattern = '^\\%load\\s+(.+)', cmd_type = arr_cmd_types[1]},
                 {pattern = '^\\%\\$[_]([a-zA-Z][a-zA-Z\\_0-9]*)\\s*=\\s*(.+)', cmd_type = arr_cmd_types[2]},
                 {pattern = '^\\%\\$([a-zA-Z][a-zA-Z\\_0-9]*)\\s*=\\s*(.+)', cmd_type = arr_cmd_types[3]},
                 {pattern = '^\\%1\\s+?(.+)', cmd_type = arr_cmd_types[4]},
                 {pattern = '^\\%2\\s+?(.+)', cmd_type = arr_cmd_types[5]},
                 {pattern = '^\\%hint\\s+?(.+)', cmd_type = arr_cmd_types[6]},
                 {pattern = '^\\%check\\s+m\\s*=\\s*([^;]+?)(?:(?:;\\s*pp\\s*=\\s*((?:\\[[^]]+?\\]\\s*?\\[[^]]*?\\];?\\s*?)+)$)|;?$)', cmd_type = arr_cmd_types[7]},
				 {pattern = '^\\%ask$', cmd_type = 'confirm'}
               }

  local command = {cmd_type = nil, matches = nil}  
  
  for _, cmd in pairs(cmds)do
   
   local matches = re.match(str, cmd.pattern)

   if(matches ~= nil)then
    command['cmd_type'] = trim(string.lower(cmd.cmd_type))
	
	if(value_exists(arr_cmd_types, command['cmd_type']))then command['matches'] = matches
	else command['matches'] = nil end
 
	break
   end
   
  end

 return command
end


function loadNames(filename, names_list, tmp_rules, rules_keys)
      default_file_path = filename

	  local rules, tmp = tmp_rules, {}
      local t = split(trim(names_list), '\n')

	  t = removeAllComments(t) -- t will be transformed from t(str, ..) to t( (str, line_number), ..)

      local wrng_names, cr_name
	  local tmp = {}
	  local i = 1
	  local tmp_class, crnt_ln
	  local new_rule = {valid = false, hint = '', has_confirm = false}
	  local rule_class = {name = ''}

	  -- reset vars_tbl.locals
	  vars_tbl.locals = {}

      while(i <= #t) do
        local can_incrmnt = true

		local cmd = get_command_type(trim(t[i].str))
        
		if(cmd.cmd_type == 'load_file')then
		        aegisub.debug.out(' cmd [load_file]: "%s" @line %d in file: "%s"\n', trim(cmd.matches[2].str), t[i].line, filename)

				local loaded_extrnl_vars = {["global"] = {}, ["locals"] = {}}
		        loaded_extrnl_vars = load_external_files(trim(cmd.matches[2].str), loaded_extrnl_vars)

			    insert_loaded_vars(vars_tbl, loaded_extrnl_vars, {filter_local_var = true})
				
				new_rule = {valid = false, hint = '', has_confirm = false}
				rule_class = {name = ''}

        elseif(cmd.cmd_type == 'global_var' or cmd.cmd_type == 'local_var')then
		        local old_i = i

				new_rule = {valid = false, hint = '', has_confirm = false}
		        vars_tbl, i = loadVars(vars_tbl, t, i, {log_vars = vars_log.log_type, fname = filename, append_to_vars = true})			

				-- "loadVars" will load all the successive "vars" starting from line[old_i] and "i" value will be set if it's loaded some vars
				-- so no need to increment the value of "i" later
				can_incrmnt = (old_i == i) -- no var were loaded and we can increment the value of "i"

		elseif(cmd.cmd_type == 'regex_match')then
		        new_rule = {valid = false, hint = '', has_confirm = false}
				rule_class = {name = ''}
         
		        local cmd_replace = t[i+1] and get_command_type(trim(t[i+1].str)) or nil

                if(cmd_replace ~= nil and cmd_replace.cmd_type == 'regex_replace')then                
                    wrng_names = applyVars(trim(cmd.matches[2].str), vars_tbl, {fname = filename, line = t[i].line, full_str = t[i].str})
                    cr_name = applyVars(trim(cmd_replace.matches[2].str), vars_tbl, {fname = filename, line = t[i+1].line, full_str = t[i+1].str})
                
                    rule_class.name = 'regex'
					new_rule.valid = true
					new_rule.hint = trim(cmd_replace.matches[2].str)
                 
                 i = i + 1
                    
                else
					 new_rule.valid = false
                	 table.insert(invalid_commands, string.format("Rule was ignored! Regex match with no replacement\n@Line %d in file: %s:\n %s\n", t[i].line, filename, trim(t[i].str)))
                	end

		elseif(cmd.cmd_type == 'check')then
		        new_rule = {valid = false, hint = '', has_confirm = false}
				rule_class = {name = ''}

			  
				    if(cmd.matches[3] ~= nil)then -- this won't happen, but I added it now for the future
					    rule_class['pp'] = {}

					    local tmp_pp_str = trim(cmd.matches[3].str)
						 
						repeat
						   local tmp_pattern = '.*?\\[([^]]+?)\\]\\s*?\\[([^]]*?)\\](.*)$'
						   local tmp_str_matches = re.match(tmp_pp_str, tmp_pattern)
						   
						   if(tmp_str_matches ~= nil)then							
							  local tmp_pp = {str_match = applyVars(tmp_str_matches[2].str, vars_tbl, {fname = filename, line = t[i].line, full_str = t[i].str}),
							                  str_replace = applyVars(tmp_str_matches[3].str, vars_tbl, {fname = filename, line = t[i].line, full_str = t[i].str})
							                 }

                              table.insert(rule_class.pp, tmp_pp) 
							  tmp_pp_str = tmp_str_matches[4].str
						   end

						until(tmp_str_matches == nil) 
						 
                         
					else 
					    local tmp_info_msg = string.format('Error! cmd [check] is missing expression "post-processing replacement:"\n')
						tmp_info_msg = tmp_info_msg .. string.format("@Line %d in file %s:\n %s\n" ,t[i].line, filename, t[i].str)
						tmp_info_msg = tmp_info_msg .. string.format("this rule will be applied without the post-processing\n")

						table.insert(invalid_commands, tmp_info_msg)
					    end



                wrng_names = applyVars(trim(cmd.matches[2].str), vars_tbl, {fname = filename, line = t[i].line, full_str = t[i].str})
                cr_name = wrng_names

                rule_class.name = 'check'
			    new_rule.valid = true
				new_rule.has_confirm = true
			    new_rule.hint = wrng_names

        elseif(cmd.cmd_type == 'confirm')then new_rule.has_confirm = true
        elseif(cmd.cmd_type == 'hint')then new_rule.hint = trim(cmd.matches[2].str)
   		elseif(cmd.cmd_type == nil)then
		        tmp = {}
		        new_rule = {valid = false, hint = '', has_confirm = false}
				rule_class = {name = ''}

   				local tmp = split(trim(t[i].str), '+') -- Format: correct_name+false_name[(\s|\/)false_name]
   
   				if(#tmp > 1)then -- split with Arabic string return inverse index   
   					wrng_names = trim(tmp[1])
   					cr_name = trim(tmp[2])

   					rule_class.name = 'normal'

					new_rule.valid = true
					new_rule.hint = cr_name
   				else 
					new_rule.valid = false
   					table.insert(invalid_commands, string.format("Misformed data ignored\n@Line %d in file %s:\n %s \n" ,t[i].line, filename, t[i].str))
   				end
		end

	    if(new_rule.valid)then -- no error after checking current "rule"
              local cmd_next = t[i+1] and get_command_type(trim(t[i+1].str)) or nil             
             
              if(cmd_next == nil or (cmd_next.cmd_type ~= 'confirm' and cmd_next.cmd_type ~= 'hint'))then

                  if(rules_keys[wrng_names] == nil)then -- not duplicate rule
					   local tmp_new_rule = {cr_name = cr_name, wrng_names = wrng_names, class = rule_class.name, confirm = new_rule.has_confirm, hint = new_rule.hint}
					   
					   if(trim(rule_class.name:lower()) == 'check' and rule_class.pp ~= nil)then
						  tmp_new_rule['check'] = rule_class.pp
					   end
							
					   table.insert(rules, tmp_new_rule)
					   rules_keys[wrng_names] = {cr_name = cr_name, class = rule_class.name, hint = new_rule.hint, filename = filename}

                  else -- possible duplicate rule

					   local tmp_info_msg = string.format('Warning! Duplicate rule exists in file: %s\n', filename)
                 	   tmp_info_msg = tmp_info_msg .. string.format('This rule already exists in file: %s\n', rules_keys[wrng_names].filename)
                 	   tmp_info_msg = tmp_info_msg .. string.format('The rule is:\n %s \n %s\nThis duplicate is ignored.\n', wrng_names, cr_name)
                 
                 	   if(rules_keys[wrng_names].class ~= rule_class.name)then
                 	     tmp_info_msg = tmp_info_msg .. string.format('Although, one is a "Regex" unlike the other,\nin file: %s\n', rules_keys[wrng_names].filename)
                 	   end
					   
					   table.insert(invalid_commands, tmp_info_msg)
                      end
              end
		  

        elseif(cmd.cmd_type == 'confirm' or cmd.cmd_type == 'hint')then
		    local tmp_info_msg = string.format('Misused command [%s] @Line: %s in file: %s.\n', cmd.cmd_type, tostring(t[i].line), filename)
		    tmp_info_msg = tmp_info_msg .. 'The [Confirm/Hint] commands come after the defined rules.\n'
			table.insert(invalid_commands, tmp_info_msg)		 
	    end

	    if(can_incrmnt)then i = i + 1 end

	  end -- end of: while(i <= #t) do
 return rules
end


function confirmThis(line_idx, rule, conf_tbl, tags)
	if(conf_tbl[line_idx] == nil)then conf_tbl[line_idx] = {nb_reviewed_rules = 0, rules = {rule}}
	else table.insert(conf_tbl[line_idx].rules, rule)end

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

         elseif(rules[j].class == 'check')then	-- to manual edit in confirm pop-up
            if(check_confirm)then		 
				local tmp_checked_str = str

				if(rules[j].check ~= nil)then -- has post-processing
				   for _, pp_expre in ipairs(rules[j].check)do
				      tmp_checked_str = re.sub(tmp_checked_str, pp_expre.str_match, pp_expre.str_replace)
				   end
				end
	 
				if(re.match(tmp_checked_str, rules[j].wrng_names) ~= nil)then
				  confirmThis(i, rules[j], needs_conf, tags)
				end
				 
		     else nbRplcdWrds = nbRplcdWrds + 1 end

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
							   if(rplcd_at_lines[tmp[k]] ~= nil)then rplcd_at_lines[tmp[k]].lines = rplcd_at_lines[tmp[k]].lines .. ' ' .. idx
							   else rplcd_at_lines[tmp[k]] = {lines = idx, cr_name = rules[j].cr_name, class = rules[j].class, hint = rules[j].hint} end
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
    local new_vars, tmp_vars = util.deep_copy(vars), util.deep_copy(vars)
	local loaded_extrnl_vars, tbl = {["global"] = {}, ["locals"] = {}}, {}
	local i, last_var_id = idx, idx
	local nb_added_vars = 0
	
	-- log_vars {1-> don't log, 2->log all, 3->globals only, 4->locals only}
	local vars_defaults = {load_all_vars = false, exclude_vars = '', log_vars = '', fname = 'undefined', append_to_vars = false}
	local options = options or vars_defaults
	
	-- init missing key+value
	options = set_defaults(options, vars_defaults)
     
	repeat
	  local matches	 
      local cmd = get_command_type(trim(t[i].str))
	 
	  if(cmd.cmd_type == 'load_file')then
 	      aegisub.debug.out(' cmd load_file: "%s" @line %d in file: "%s"\n', trim(cmd.matches[2].str), t[i].line, options.fname)
		  loaded_extrnl_vars = load_external_files(trim(cmd.matches[2].str), loaded_extrnl_vars)

		  insert_loaded_vars(tmp_vars, loaded_extrnl_vars)
		 
		  last_var_id = i + 1

	  elseif(cmd.cmd_type == 'global_var')then
          matches = cmd.matches
          
          if(trim(string.lower(options.exclude_vars)) ~= 'global')then
			  local var_key = trim(string.lower(matches[2].str))
		   
			  -- log updates of global vars if possible
			  if(new_vars.global[var_key] and (options.log_vars == '2' or options.log_vars == '3'))then
				local log_entry = string.format('Global constant "%s" was set @line: %d in file: %s\nFrom: %s\nTo: %s\n\n',
												 var_key, t[i].line, options.fname, new_vars.global[var_key], trim(matches[3].str))
			  
				table.insert(vars_log.entries, log_entry)
			  end
			
			  -- if the current var value has other vars in it then apply them
			  if(has_var(trim(matches[3].str)))then
				   new_vars.global[string.lower(matches[2].str)] = applyVars(trim(matches[3].str), tmp_vars, {fname = options.fname, line = t[i].line, full_str = t[i].str})
				   tmp_vars.global[string.lower(matches[2].str)] = new_vars.global[string.lower(matches[2].str)]
			  else 
				   new_vars.global[string.lower(matches[2].str)] = trim(matches[3].str)
				   tmp_vars.global[string.lower(matches[2].str)] = new_vars.global[string.lower(matches[2].str)]
				  end
				
			  nb_added_vars = nb_added_vars + 1
			  last_var_id = i + 1	
          end
       	
          
   
	  elseif(cmd.cmd_type == 'local_var')then
          matches = cmd.matches
          local var_key = trim(string.lower(matches[2].str))
          local current_local_var = fields_lookup(new_vars.locals, {var_key, options.fname, 'val'})

          -- if the current var value has other vars in it then apply them
          local remove_or_keep = (trim(string.lower(options.exclude_vars)) == 'local')
          local tmp_local_var
          
          if(has_var(trim(matches[3].str)))then 
		       tmp_local_var = applyVars(trim(matches[3].str), tmp_vars, {fname = options.fname, line = t[i].line, full_str = t[i].str})
          else 
		       tmp_local_var = trim(matches[3].str)
			  end 

          -- set or insert the new local var
          init_fields(new_vars.locals, {val = tmp_local_var, discard = remove_or_keep}, {var_key, options.fname})
          init_fields(tmp_vars.locals, {val = tmp_local_var, discard = remove_or_keep}, {var_key, options.fname})
          
          -- log the updated local var if needed
          if(current_local_var ~= nil and (options.log_vars == '2' or options.log_vars == '4'))then
            local log_entry = string.format('Local constant "%s" was set @line: %d in file: %s\nFrom: %s\nTo: %s\n\n',
          							         var_key, t[i].line, options.fname, current_local_var, tmp_local_var)
            table.insert(vars_log.entries, log_entry)
          end
          
          
          nb_added_vars = nb_added_vars + 1                
          last_var_id = i + 1
	  end

     i = i + 1
	until( ( (cmd.cmd_type == nil or not value_exists({'load_file', 'global_var', 'local_var'}, cmd.cmd_type)) and not options.load_all_vars) or i > #t)

 -- append global and local(non-external) vars loaded from external files
 if(options.append_to_vars)then
  insert_loaded_vars(new_vars, loaded_extrnl_vars, {filter_local_var = true})
 end
   
 return new_vars, last_var_id, nb_added_vars
end


function applyVars(val, vars, options)
    local str = val
	local tmp_str = ''
	
	local vars_defaults = {fname = nil, line = nil}
	local options = options or vars_defaults
		
	-- init missing key+value
	options = set_defaults(options, vars_defaults)
	
	log_expression_updates(expr_update_log, options)

	local pattern  = '\\%(_?[a-zA-Z][a-zA-Z_0-9]*)\\%'		
	
	repeat
	 local matches = re.match(str, pattern)
	 
	 local isGlobal, apply = false, false
	 
	 if(matches ~= nil)then   
	   isGlobal = (string.utf8sub(matches[2].str, 1, 1) == '_')
	   
	   local key_global = string.lower(string.utf8sub(matches[2].str, 2, -1))
	   local key_local = string.lower(matches[2].str)
	   
	   --apply = (isGlobal and vars.global[key_global] ~= nil) or (not isGlobal and vars.locals[key_local] ~= nil)
	   apply = (isGlobal and vars.global[key_global] ~= nil) or (not isGlobal and fields_lookup(vars.locals, {key_local, options.fname, 'val'}) ~= nil)
	   
	   if(apply)then
	    local str_2b_updated = options.full_str

	    if(isGlobal)then
 		 str = re.sub(str, matches[1].str, vars.global[key_global])		 
		 str_2b_updated = str_2b_updated and re.sub(str_2b_updated, matches[1].str, vars.global[key_global]) or nil
	    else 
		      local current_tmp_local_var = fields_lookup(vars.locals, {key_local, options.fname, 'val'})
		      str = re.sub(str, matches[1].str, current_tmp_local_var)
			  str_2b_updated = str_2b_updated and re.sub(str_2b_updated, matches[1].str, current_tmp_local_var) or nil
		     end
		
        -- insert and log the updated expression
        if(str_2b_updated and str_2b_updated ~= options.full_str)then
		  options.full_str = str_2b_updated
		  log_expression_updates(expr_update_log, options)
		end			 
		
	   else -- undefined global/local-> log and notify about it then test the rest of the non-matched sub-string
	        
		   -- log the missing constant
		   if(isGlobal)then
                local expre_line_tmp = fields_lookup(expr_update_log, {options.fname, 'lines', options.line})			 
                local expre_update_id = expre_line_tmp and #expre_line_tmp or 0
                
                -- log the current missing global constant
                if(fields_lookup(vars_log.undefined_vars.global, {options.fname, options.line, key_global}) == nil)then
                  init_fields(vars_log.undefined_vars.global, expre_update_id, {options.fname, options.line, key_global})
                end

		   else
                local expre_line_tmp = fields_lookup(expr_update_log, {options.fname, 'lines', options.line})			 
                local expre_update_id = expre_line_tmp and #expre_line_tmp or 0
                
                -- log the current missing local constant
                if(fields_lookup(vars_log.undefined_vars.locals, {options.fname, options.line, key_local}) == nil)then
                  init_fields(vars_log.undefined_vars.locals, expre_update_id, {options.fname, options.line, key_local})
                end

			   end

		   
		   -- tmp_str = str:utf8sub(1, matches[1].last)
           -- utf8sub could not work correctly if used with a non-ASCII string		   
		   -- it uses str:sub(first_byte, last_byte) that somehow treats 2 bytes as if they are 1 byte
		   -- for example this string: str = م%a_var%x (م is 2 bytes) 
		   -- and the result of: str:utf8sub(1, matches[1].last) as str:utf8sub(1, 9)
		   -- will produce م%a_var%x rather than م%a_var%

		   local tmp_pattern = '^(.*?\\%_?[a-zA-Z][a-zA-Z_0-9]*\\%)(.*)$'
		   local tmp_str_matches = re.match(str, tmp_pattern)
		   
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
function split(s, delim)

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


function has_var(str)	 
 return (str ~= nil and re.match(str, '\\%(_?[a-zA-Z][a-zA-Z_0-9]*)\\%') ~= nil)
end


-- tbr
function print_vars(vars)
   for key_type, arr_vars in pairs(vars) do
   
    if(string.lower(key_type) == 'global')then
	  for k, v in pairs(arr_vars) do
       aegisub.debug.out('_%s = %s\n', k, v);
      end
	  
	elseif(string.lower(key_type) == 'locals')then  
	  for k, f in pairs(arr_vars) do
	   for fname, shit in pairs(f) do
        aegisub.debug.out('%s = %s , discard = %s in file: %s\n', k, tostring(shit.val), tostring(shit.discard), fname)
	   end	

      end
	end
    
  end
end



function insert_loaded_vars(src_vars, loaded_vars, options)
   local options_defaults = {ignore_vars_type = '', filter_local_var = false}
   local options = options or options_defaults
		
	-- init missing key+value
   options = set_defaults(options, options_defaults)

   for key_type, arr_vars in pairs(loaded_vars) do
   
    if(trim(options.ignore_vars_type:lower()) ~= 'global' and string.lower(key_type) == 'global')then
	  for key_global, var_value in pairs(arr_vars) do
	   
	   -- copy only non-existing vars & prioritize vars defined in the current file over the loaded ones from external files
	   if(src_vars.global[trim(string.lower(key_global))] == nil)then
         src_vars.global[trim(string.lower(key_global))] = var_value
       end   
	   
      end
	  
	elseif(trim(options.ignore_vars_type:lower()) ~= 'locals' and string.lower(key_type) == 'locals')then  
	  for key_local, f in pairs(arr_vars) do
	   for fname, data in pairs(f) do
	   
	    if((not options.filter_local_var) or (options.filter_local_var and not data.discard))then 
		 init_fields(src_vars.locals, {val = data.val, discard = data.discard}, {key_local, fname})
		end
        --aegisub.debug.out('%s = %s , discard = %s in file: %s\n', key_local, tostring(data.val), tostring(data.discard), fname)
	   end	

      end
	end
    
  end
end



function fields_lookup(obj, args)
    local unpack = table.unpack or unpack
    local sze = args and #args or 0

    if(obj == nil or sze == 0) then return nil, sze
    else 
        if(sze > 1)then
            if(obj[args[1]] == nil)then return nil, sze
            elseif(type(obj[args[1]]) ~= 'table')then return nil, -1
            else return fields_lookup(obj[args[1]], {unpack(args, 2)})
                end
        else return obj[args[1]], sze
            end
        end
end


function init_fields(obj, value, args)
     local unpack = table.unpack or unpack
     local sze = #args

     if(sze == 1)then obj[args[sze]] = value
     else    
          if(obj[args[1]] == nil or type(obj[args[1]]) ~= 'table' )then
           obj[args[1]] = {}
          end 

          init_fields(obj[args[1]], value, {unpack(args, 2)})
         end         
     

end

function log_expression_updates(expr_log, options)
    local vars_defaults = {fname = nil, line = nil}
	local options = options or vars_defaults
		
	-- init missing key+value
	options = set_defaults(options, vars_defaults)
	
	-- log expression values updates if possible
	if(options.fname ~= nil and options.line ~= nil and options.full_str ~= nil)then
	 local expre_line, lvl = fields_lookup(expr_log, {options.fname, 'lines', options.line})
	 
	 if(expre_line == nil)then init_fields(expr_log, {options.full_str}, {options.fname, 'lines', options.line})
	 elseif(not value_exists(expre_line, options.full_str))then table.insert(expre_line, options.full_str) end

	end
	
end	


-- sorted non-numiric table keys iterator
function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do table.insert(keys, k) end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

aegisub.register_macro(script_name, script_description, appContext)
