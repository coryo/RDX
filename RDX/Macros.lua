if not RDX.Macros then RDX.Macros = {}; end

RDX.Macros.list = {}

local MAX_MACROS = 18;

function RDX.Macros.GetList()
    RDX.Macros.BuildList();
    return RDX.Macros.list;
end


function RDX.Macros.BuildList()
	local ret = {};
	
	local mType, numMacros;
	local numAccountMacros, numCharacterMacros = GetNumMacros();
	local name, texture, body;

	for j = 0, MAX_MACROS, MAX_MACROS do
		if (j == 0) then
			numMacros = numAccountMacros;
			mType = 0;
		else
			numMacros = numCharacterMacros;
			mType = 1;
		end;
		for i = 1, MAX_MACROS do
			local macroID = i + j;
			
			if ( i <= numMacros ) then
				name, _, body, _ = GetMacroInfo(macroID);
				
				if (strlen(body) > 0) then
					local info = {};
					info.name = name;
					info.type = mType;
					info.id = macroID;
					info.text = name;
					table.insert(ret, info);
				end;
			end;
		end;
	end;

    RDX.Macros.list = ret
end

-------
 function RDX.Macros.RunMacro(index)
  	-- close edit boxes, then enter body line by line
  	if (MacroFrame_SaveMacro) then
  		MacroFrame_SaveMacro();
  	end;
  	local body;
  	if (type(index) == "number") then
  		_, _, body, _ = GetMacroInfo(index);
  	elseif (type(index) == "string") then
  		_, _, body, _ = GetMacroInfo(GetMacroIndexByName(index));
  	end;
  	if (not body) then return; end;
  
  	if (ChatFrameEditBox:IsVisible()) then
  		ChatEdit_OnEscapePressed(ChatFrameEditBox);
  	end
  	if (ReplaceAlias and ASFOptions.aliasOn) then
  		-- correct aliases
  		body = ReplaceAlias(body);
  	end;
  	while (strlen(body) > 0) do
  		local block, line;
  		body, block, line = RDX.Macros.FindBlock(body);
  		if (block) then
  			RunScript(block);
  		else
  			RDX.Macros.RunLine(line);
  		end;
  	end;
end;
--  
function RDX.Macros.FindBlock(body)
  	local a, b, block = strfind(body, "^/script (%-%-%-%-%[%[.-%-%-%-%-%]%])[\n]*");
  	if (block) then
  		body = strsub(body, b+1);
  		return body, block;
  	end;
  	local a, b, line = strfind(body, "^([^\n]*)[\n]*");
  	if (line) then
  		body = strsub(body,b+1);
  		return body, nil, line;
  	end;
end;
--  
function RDX.Macros.RunBody(text)
  	local body=text;
  	local length = strlen(body);
  	for w in string.gfind(body, "[^\n]+") do
  		RunLine(w);
  	end;
end;
 
function RDX.Macros.RunLine(...)
  -- execute a line in a macro
  -- if script or cast, then rectify and RunScript
  -- else send to chat edit box
    for k = 1, arg.n do
    	local text = arg[k];
    	if (ReplaceAlias and ASFOptions.aliasOn) then
    		-- correct aliases
    		text = ReplaceAlias(text);
    	end;
    	if (string.find(text, "^/cast") ) then
    		local i, book = RDX.Macros.SM_FindSpell(gsub(text, "^%s*/cast%s*(%w.*[%w%)])%s*$", "%1"));
    		if (i) then
    			CastSpell(i, book);
    		end
    	else
    		if (string.find(text, "^/script ")) then
    			RunScript(gsub(text, "^/script ", ""));
    		else
    			text = gsub(text, "\n", ""); -- cannot send newlines, will disconnect
    			ChatFrameEditBox:SetText(text);
    			ChatEdit_SendText(ChatFrameEditBox);
    		end;
    	end;
    end; -- for
end; -- RunLine()
--  
function RDX.Macros.SM_FindSpell(spell)
  	local s = gsub(spell, "%s*(.-)%s*%(.*","%1");
  	local r;
  	local num = tonumber(gsub(spell, "%D*(%d+)%D*", "%1"), 10);
  	if (string.find(spell, "%(%s*[Rr]acial")) then
  		r = "racial";
  	elseif (string.find(spell, "%(%s*[Ss]ummon")) then
  		r = "summon";
  	elseif (string.find(spell, "%(%s*[Aa]pprentice")) then
  		r = "apprentice";
  	elseif (string.find(spell, "%(%s*[Jj]ourneyman")) then
  		r = "journeyman";
  	elseif (string.find(spell, "%(%s*[Ee]xpert")) then
  		r = "expert";
  	elseif (string.find(spell, "%(%s*[Aa]rtisan")) then
  		r = "artisan";
  	elseif (string.find(spell, "%(%s*[Mm]aster")) then
  		r = "master";
  	elseif (string.find(spell, "[Rr]ank%s*%d+") and num and num > 0) then
  		r = gsub(spell, ".*%(.*[Rr]ank%s*(%d+).*", "Rank "..num);
  	else
  		r = ""
  	end;
  	return RDX.Macros.FindSpell(s,r);
end;
--  
function RDX.Macros.FindSpell(spell, rank)
  	local i = 1;
  	local booktype = { "spell", "pet", };
  	--local booktype = "spell";
  	local s,r;
  	local ys, yr;
  	for k, book in booktype do
  		while spell do
  		s, r = GetSpellName(i,book);
  		if ( not s ) then
  			i = 1;
  			break;
  		end;
  		if ( string.lower(s) == string.lower(spell)) then ys=true; end;
  		if ( (r == rank) or (r and rank and string.lower(r) == string.lower(rank))) then yr=true; end;
  		if ( rank=='' and ys and (not GetSpellName(i+1, book) or string.lower(GetSpellName(i+1, book)) ~= string.lower(spell) )) then
  			yr = true; -- use highest spell rank if omitted
  		end;
  		if ( ys and yr ) then
  			return i,book;
  		end;
  		i=i+1;
  		ys = nil;
  		yr = nil;
  		end;
  	end;
  	return;
end;
----------