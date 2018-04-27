script_name = "Replace text"
script_description = "Replace text as user defined"
script_author = "LORD47"
script_version = "2.0"

re = require 'aegisub.re'

include("unicode.lua")
include("utf8.lua")

function appContext(subtitles, selected_lines, active_line)
	local tmp_conf = {}
	local tmp_tbl = {}
	local cfg_res = ""

    repeat
     cfg_res, config = aegisub.dialog.display(tmp_conf, {"Replace Text", "Help", "Close"} )

     if(tostring(cfg_res) ~= "false")then
      if(string.lower(cfg_res) == "replace text")then replaceNames(subtitles, selected_lines, active_line)
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
				tmp_tbl = { class = "label"; label = "Original:";  x = 0; y = (pos_y + 2); height = 1; width = 1; }
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
	 end -- end of: if(#needs_conf > 0)then

	 showStats(rplcd_at_lines)

    end -- end of: for file_idx = 1, #filenames do

    aegisub.debug.out('\nReplaced %d word(s).\n', nbRplcdWrds)
  end -- end of: if(filenames ~= nil)	
end


function removeAllComments(t)

	 for i = #t, 1, -1 do
       if(isempty(t[i]) or re.match(trim(t[i]), '^#.*') ~= nil)then
	    table.remove(t, i)
	   end
     end
end


function loadNames(filename, names_list, tmp_rules, rules_keys)
      --local name, fls_names = {}, {}
	  local rules, tmp = tmp_rules, {}
      t = split(trim(names_list), '\n')

	  removeAllComments(t)

	  local tmp = {}
	  local i = 1
	  local tmp_class, crnt_ln
	  local rule_class = ''
	  local hint = ''
	  local new_rule_valid = false

      while(i <= #t) do
		new_rule_valid = false

		_, _, tmp_class = trim(t[i]):find('^(%%[%d]*)')

		-- %1 regex_to_check_against
		if(tmp_class ~= nil and tmp_class == '%1')then -- it's not misformed Regex (starts with a % but not with %1)
		tmp = {}
		tmp[1] = trim(string.sub(trim(t[i]), string.len(tmp_class) + 1))

		-- %2 string_to_replace_with
		if(t[i+1] ~= nil and string.sub(trim(t[i+1]), 1, 2) == '%2')then
		tmp[2] = trim(string.sub(trim(t[i+1]), 3))
		i = i + 1

		wrng_names = trim(tmp[1])
		cr_name = trim(tmp[2])
		hint = cr_name 
		rule_class = 'regex'
		new_rule_valid = true
		else
			new_rule_valid = false	
			aegisub.debug.out("\nRule was ignored! Regex match with no replacement rule @Line %d:\n %s \n-----------------------------------------------------------", i, trim(t[i]))
			end

		elseif(tmp_class ~= nil)then aegisub.debug.out("\nMisformed rule was ignored @Line %d:\n %s\n----------------------------------", i, trim(t[i]))
		elseif(tmp_class == nil)then
				local tmp = split(trim(t[i]), '+') -- Format: correct_name+false_name[(\s|\/)false_name]

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
					aegisub.debug.out("\nMisformed data ignored @Line: " .. i .. " : " .. t[i])
				end
		end

	    if(new_rule_valid)then -- no error after checking current "rule"
		 -- %ask -> confirm replacement
		 local confirm = false

		 if(t[i+1] ~= nil and string.lower(string.sub(trim(t[i+1]), 1, 4)) == '%ask')then
		  confirm = true
		  i = i + 1
		 end

		 -- %hint (description about the current "rule", if it's not available -> use the "wrng_names" as "hint"
		 if(t[i+1] ~= nil and string.lower(string.sub(trim(t[i+1]), 1, 5)) == '%hint')then
		  -- copy the string after "%ask"
		  hint = string.lower(trim(string.sub(trim(t[i+1]), 6)))

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
			   str, nbRep = string.gsub(str, "%" .. trim(tmp[k]), rules[j].cr_name)
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
					  '\n\n  3-Lines that start with  # are treated as comments and thus ignonred (so is for empty lines).'

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

aegisub.register_macro(script_name, script_description, appContext)
