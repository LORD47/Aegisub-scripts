local uiLocalization = {Languages = {}}
local currentLang = "en"

function uiLocalization.setLocale(newLocale)
  currentLang = newLocale
end

function uiLocalization.getLocale()
  return currentLang
end

local function translate(field_path, defaultLangData, options)
  local data_path

  if(type(field_path):lower() == "string")then data_path = uiLocalization.split(trim(field_path), '.')
  else data_path = uiLocalization.is_array(field_path) and field_path or nil end

  if(data_path)then
     local dflt_res = uiLocalization.fields_lookup(defaultLangData, data_path)

	 if(dflt_res ~= nil)then
        local default_options = {default_lang_only = false, root = 'ui'}
        local options = options and type(options):lower() == 'table' and options or default_options
	    options = uiLocalization.set_defaults(options, default_options)

		options['type'] = uiLocalization.is_array(dflt_res) and 'array' or type(dflt_res)
		options['size'] = options.type:lower() == 'array' and #dflt_res or nil

	    if(not options.default_lang_only)then
           local result = uiLocalization.fields_lookup(uiLocalization.Languages[uiLocalization.getLocale()].ui, data_path)

	  	   if(result ~= nil)then
	          result = uiLocalization.validate_data(result, options)

	          if(result.error == nil)then return result end
           end
	    end

	    return uiLocalization.validate_data(dflt_res, options)
     else return {error = "Default_Field_Not_Defined"}  end

  else return {error = "undefined 2"} end

end


function uiLocalization.validate_data(data, options)
  local result = data

  if(options.type:lower() == "string")then return result and type(result):lower() ~= "table" and tostring(result) or {error = 'undefined 3'}
  elseif(options.type:lower() == "array")then
     if(result)then

	    if(uiLocalization.is_array(result))then

		    if(options.size)then
			   if(options.size == #data)then return data
			   else return {error = 'Mismatched Result Array size'} end
			else return data end

		else return {error = string.format('Expected array got: "%s".', type(data))} end

	 else return {error = 'undefined 4'} end

  else return {error = 'undefined data type'} end	 

end

function uiLocalization.is_array(t)

  if(type(t) ~= 'table')then return false end

  local i = 0

  for _ in pairs(t) do
     i = i + 1
     if(t[i] == nil)then return false end
  end

  return true
end


-- split a string on a delimiter
function uiLocalization.split(s, sep)
    if(sep and sep:len() > 0)then
        local fields = {}

        local pattern = string.format("([^%s]+)", sep)
        string.gsub(s, pattern, function(c) table.insert(fields, c) end)

        return fields

    else return {s} end
end


function uiLocalization.fields_lookup(obj, args)
    local unpack = table.unpack or unpack
    local sze = args and #args or 0

    if(obj == nil or sze == 0) then return nil, sze
    else 
	     if(sze > 1)then
             if(obj[args[1]] == nil)then return nil, sze
             elseif(type(obj[args[1]]) ~= 'table')then return nil, -1
             else return uiLocalization.fields_lookup(obj[args[1]], {unpack(args, 2)})
                 end
         else return obj[args[1]], sze end
        end
end


function uiLocalization.set_defaults(tbl, vals)
   for k, v in pairs(vals)do
    if(tbl[k] == nil)then
	 tbl[k] = v
	end
   end

 return tbl
end

uiLocalization.translate = translate


setmetatable(uiLocalization, {__call = function(_,...) return translate(id) end})

return uiLocalization