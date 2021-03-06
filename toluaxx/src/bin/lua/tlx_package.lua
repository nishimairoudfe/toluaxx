-- tolua: package class
-- Written by Waldemar Celes
-- TeCGraf/PUC-Rio
-- Jul 1998
-- $Id: tlx_package.lua,v 1.6 2007-08-25 11:07:04 phoenix11 Exp $

-- This code is free software; you can redistribute it and/or modify it.
-- The software provided hereunder is on an "as is" basis, and
-- the author has no obligation to provide maintenance, support, updates,
-- enhancements, or modifications.



-- Package class
-- Represents the whole package being bound.
-- The following fields are stored:
--    {i} = list of objects in the package.
classPackage={
   classtype='package'
}
classPackage.__index=classPackage
setmetatable(classPackage,classContainer)

-- Print method
function classPackage:print ()
   print("Package: "..self.name)
   local i=1
   while self[i] do
      self[i]:print("","")
      i = i+1
   end
end

function classPackage:preprocess ()
   -- avoid preprocessing embedded Lua code
   local L = {}
   self.code = gsub(self.code,"\n%s*%$%[","\1") -- deal with embedded lua code
   self.code = gsub(self.code,"\n%s*%$%]","\2")
   self.code = gsub(self.code,"(%b\1\2)", function (c)
					     tinsert(L,c)
					     return "\n#["..getn(L).."]#"
					  end)
   -- avoid preprocessing embedded C code
   local C = {}
   self.code = gsub(self.code,"\n%s*%$%<","\3") -- deal with embedded C code
   self.code = gsub(self.code,"\n%s*%$%>","\4")
   self.code = gsub(self.code,"(%b\3\4)", function (c)
					     tinsert(C,c)
					     return "\n#<"..getn(C)..">#"
					  end)
   -- avoid preprocessing embedded C code
   self.code = gsub(self.code,"\n%s*%$%{","\5") -- deal with embedded C code
   self.code = gsub(self.code,"\n%s*%$%}","\6")
   self.code = gsub(self.code,"(%b\5\6)", function (c)
					     tinsert(C,c)
					     return "\n#<"..getn(C)..">#"
					  end)
   
   --self.code = gsub(self.code,"\n%s*#[^d][^\n]*\n", "\n\n") -- eliminate preprocessor directives that don't start with 'd'
   self.code = gsub(self.code,"\n[ \t]*#[ \t]*[^d%<%[]", "\n//") -- eliminate preprocessor directives that don't start with 'd'
   
   -- avoid preprocessing verbatim lines
   local V = {}
   self.code = gsub(self.code,"\n(%s*%$[^%[%]][^\n]*)",function (v)
							  tinsert(V,v)
							  return "\n#"..getn(V).."#"
						       end)
   
   -- perform global substitution
   
   self.code = gsub(self.code,"(//[^\n]*)","")     -- eliminate C++ comments
   self.code = gsub(self.code,"/%*","\1")
   self.code = gsub(self.code,"%*/","\2")
   self.code = gsub(self.code,"%b\1\2","")
   self.code = gsub(self.code,"\1","/%*")
   self.code = gsub(self.code,"\2","%*/")
   self.code = gsub(self.code,"%s*@%s*","@") -- eliminate spaces beside @
   self.code = gsub(self.code,"%s?inline(%s)","%1") -- eliminate 'inline' keyword
   --self.code = gsub(self.code,"%s?extern(%s)","%1") -- eliminate 'extern' keyword
   --self.code = gsub(self.code,"%s?virtual(%s)","%1") -- eliminate 'virtual' keyword
   --self.code = gsub(self.code,"public:","") -- eliminate 'public:' keyword
   self.code = gsub(self.code,"([^%w_])void%s*%*","%1_userdata ") -- substitute 'void*'
   self.code = gsub(self.code,"([^%w_])void%s*%*","%1_userdata ") -- substitute 'void*'
   self.code = gsub(self.code,"([^%w_])char%s*%*","%1_cstring ")  -- substitute 'char*'
   self.code = gsub(self.code,"([^%w_])lua_State%s*%*","%1_lstate ")  -- substitute 'lua_State*'
   
   -- restore embedded Lua code
   self.code = gsub(self.code,"%#%[(%d+)%]%#",function (n)
						 return L[tonumber(n)]
					      end)
   -- restore embedded C code
   self.code = gsub(self.code,"%#%<(%d+)%>%#",function (n)
						 return C[tonumber(n)]
					      end)
   -- restore verbatim lines
   self.code = gsub(self.code,"%#(%d+)%#",function (n)
					     return V[tonumber(n)]
					  end)
   
   self.code = string.gsub(self.code, "\n%s*%$([^\n]+)", function (l)
							    Verbatim(l.."\n")
							    return "\n"
							 end)
end

-- translate verbatim
function classPackage:preamble ()
   output('/*\n')
   output(' * Lua binding: '..self.name..'\n')
   output(' * Generated automatically by '..tolua.name..' '..tolua.version..'\n')
   output(' * on '..date()..'\n')
   output(' * for Lua '..tolua.lua_version..'\n')
   output(' */\n\n')
   
   output('#ifndef __cplusplus\n')
   output('#include "stdlib.h"\n')
   output('#endif\n')
   output('#include "string.h"\n\n')
   output('#include "toluaxx.h"\n\n')

   output('#ifdef __cplusplus\n')
   output('#include<string>\n')
   output('inline const char* tolua_tocppstring(lua_State* L, int narg, std::string def){return tolua_tocppstring(L,narg,def.c_str());}\n')
   output('inline const char* tolua_tofieldcppstring(lua_State* L, int lo, int index, std::string def){return tolua_tofieldcppstring(L,lo,index,def.c_str());}\n')
   output('#endif\n')
   
   if not flags.header then
      output('/* Exported function */')
      output('TOLUA_API int tolua_'..self.name..'_open (lua_State* tolua_S);')
      output('\n')
   end
   
   local i=1
   while self[i] do
      self[i]:preamble()
      i = i+1
   end
   
   if self:requirecollection(_collect) then
      output('\n')
      output('/* function to release collected object via destructor */')
      output('#ifdef __cplusplus\n')
      for i,v in pairs(_collect) do
	 output('\nstatic int '..v..' (lua_State* tolua_S)')
	 output('{')
	 output(' '..i..'* self = ('..i..'*) tolua_tousertype(tolua_S,1,0);')
	 output('	delete self;')
	 output('	return 0;')
	 output('}')
      end
      output('#endif\n\n')
   end
   
   output('\n')
   output('/* function to register type */')
   output('static void tolua_reg_types (lua_State* tolua_S)')
   output('{')
   foreach(_usertype,function(n,v) output(' tolua_usertype(tolua_S,"',v,'");') end)
   if flags.typeidlist then
      output("#ifndef Mtolua_typeid\n#define Mtolua_typeid(L,TI,T)\n#endif\n")
      foreach(_usertype,function(n,v) output(' Mtolua_typeid(tolua_S,typeid(',v,'), "',v,'");') end)
   end
   output('}')
   output('\n')
end

-- register package
-- write package open function
function classPackage:register (pre)
   pre = pre or ''
   push(self)
   output(pre.."/* Open function */")
   output(pre.."TOLUA_API int tolua_"..self.name.."_open (lua_State* tolua_S)")
   output(pre.."{")
   output(pre.." tolua_open(tolua_S);")
   output(pre.." tolua_reg_types(tolua_S);")
   output(pre.." tolua_module(tolua_S,NULL,",self:hasvar(),");")
   output(pre.." tolua_beginmodule(tolua_S,NULL);")
   local i=1
   while self[i] do
      self[i]:register(pre.."  ")
      i = i+1
   end
   output(pre.." tolua_endmodule(tolua_S);")
   output(pre.." return 1;")
   output(pre.."}")
   
   output("\n\n")
   output("#if defined(LUA_VERSION_NUM) && LUA_VERSION_NUM >= 501\n");
   output(pre.."TOLUA_API int luaopen_"..self.name.." (lua_State* tolua_S) {")
   output(pre.." return tolua_"..self.name.."_open(tolua_S);")
   output(pre.."};")
   output("#endif\n\n")

   if flags.maingen then
      output('/* Main function */')
      output('int main(int argc, char* argv[]){')
      output('#  if LUA_VERSION_NUM >= 501 /* lua 5.1 */')
      output('  lua_State* tolua_S=luaL_newstate();')
      output('  luaL_openlibs(tolua_S);')
      output('#  else\n')
      output('  lua_State* tolua_S=lua_open();')
      output('  luaopen_base(tolua_S);')
      output('  luaopen_io(tolua_S);')
      output('  luaopen_string(tolua_S);')
      output('  luaopen_table(tolua_S);')
      output('  luaopen_math(tolua_S);')
      output('  luaopen_debug(tolua_S);')
      output('#  endif\n')
      output('  {')
      output('    lua_newtable(tolua_S);')
      output('    lua_pushvalue(tolua_S,-1);')
      output('    lua_setglobal(tolua_S,"arg");')
      output('    {')
      output('#     if LUA_VERSION_NUM >= 501 /* lua 5.1 */')
      output('#     else\n')
      output('        lua_pushstring(tolua_S,"n");')
      output('        lua_pushnumber(tolua_S,argc);')
      output('        lua_settable(tolua_S,-3);')
      output('#     endif\n')
      output('      for(int i=0;i<argc;i++){')
      output('        lua_pushnumber(tolua_S,i);')
      output('        lua_pushstring(tolua_S,argv[i]);')
      output('        lua_settable(tolua_S,-3);')
      output('      }')
      output('    }')
      output('    lua_pop(tolua_S,1);')
      output('  }')
      output('  tolua_'..self.name..'_open(tolua_S);')
      output('  lua_close(tolua_S);')
      output('  return 0;')
      output('}')
   end
   
   pop()
end

-- write header file
function classPackage:header ()
   output('/*\n') output('** Lua binding: '..self.name..'\n')
   output(' * Generated automatically by '..tolua.name..' '..tolua.version..'\n')
   output(' * on '..date()..'\n')
   output(' * for Lua '..tolua.lua_version..'\n')
   output(' */\n\n')
   
   if not flags.header then
      output('/* Exported function */')
      output('TOLUA_API int tolua_'..self.name..'_open (lua_State* tolua_S);')
      output('\n')
   end
end

-- Internal constructor
function _Package (self)
   setmetatable(self,classPackage)
   return self
end

-- Parse C header file with tolua directives
-- *** Thanks to Ariel Manzur for fixing bugs in nested directives ***
function extract_code(fn,s)
   local code='\n$#include "'..fn..'"\n'
   
   s="\n"..s.."\n" -- add blank lines as sentinels
   local _,e,c,t=strfind(s,"\n([^\n]-)[Tt][Oo][Ll][Uu][Aa]_([^%s]*)[^\n]*\n")
   while e do
      t=strlower(t)
      if t=="begin" then
	 _,e,c=strfind(s,"(.-)\n[^\n]*[Tt][Oo][Ll][Uu][Aa]_[Ee][Nn][Dd][^\n]*\n",e)
	 if not e then
	    tolua_error("Unbalanced 'tolua_begin' directive in header file")
	 end
	 --- delete code with // tolua_noexport ---
	 c=string.gsub(c,"\n[^\n]-[Tt][Oo][Ll][Uu][Aa]_[Nn][Oo][Ee][Xx][Pp][Oo][Rr][Tt][^\n]*\n","\n")
      elseif t=="export" then
	 
      elseif t=="readonly" then
	 
      elseif t=="property" then
	 
      elseif t=="property__overload" then
	 
      else
	 tolua_error("Unsupported directive 'tolua_"..t.."' in header file")
      end
      code=code..c.."\n"
      _,e,c,t=strfind(s,"\n([^\n]-)[Tt][Oo][Ll][Uu][Aa]_([^%s]*)[^\n]*\n",e)
   end
   --- ancomment /** **/ ---
   --code=string.gsub(code,"%/%*%*(.-)%*%*%/","%1")
   code=string.gsub(code,"%/%*%$(.-)%$%*%/","%1")
   return code
end

function extract_path(fn)
   if string.find(fn,"%/") then
      return string.gsub(fn,"(.+%/).+","%1")
   end
   return ""
end

-- Constructor
-- Expects the package name, the file extension, and the file text.
function Package (name,input)
   local code = ""
   for _,ifn in pairs(input) do -- multiple input files
      local ext = "pxx"
      
      -- open input file, if any
      if ifn then
	 local st, msg = readfrom(ifn)
	 if not st then
	    error('#'..msg)
	 end
	 local _; _, _, ext = strfind(ifn,".*%.(.*)$")
      end
      local chunk = "\n" .. read('*a')
      if ext == 'h' or ext == 'hpp' or ext == 'hxx' then
	 chunk = extract_code(ifn,chunk)
      end
      
      -- $arg directive process
      repeat
	 chunk,nsubst = gsub(chunk,'(\n%s*%$arg%s*([^\n]*))',
			     function(code,args)
				local arg={}
				gsub(args,'([^%s]+)',
				     function(a)
					arg[#arg+1]=a
				     end)
				local c=cmdline_process(arg)
				cmdline_postproc(c)
				return ''
			     end)
      until nsubst==0

      --print("[[[[[["..chunk.."]]]]]]")

      -- close file
      if ifn then
	 readfrom()
      end
      
      -- deal with include directive
      local nsubst
      repeat
	 chunk,nsubst = gsub(chunk,'\n%s*%$(.)file%s*"(.-)"([^\n]*)',
			    function(kind,fn,extra)
			       local _,_,ext=strfind(fn,".*%.(.*)$")
			       local _fn=extract_path(ifn)..fn
			       local fp,mf=openfile(_fn,'r') -- try open fn in .pxx catalog
			       local msg=mf or ""
			       if not fp then
				  fp,mf=openfile(fn,'r')
				  if not fp and fn~=_fn then
				     msg=msg.."\n          "..mf
				  end
			       end
			       if not fp then
				  if flags.include_path then
				     for _,n in pairs(flags.include_path) do
					if string.sub(n,-1)~="/" then n=n.."/" end
					fp,mf=openfile(n..fn,'r')
					if not fp then
					   msg=msg.."\n          "..mf
					end
				     end
				  end
			       end
			       if not fp then
				  error('#'..msg..'')
			       end
			       local s=read(fp,'*a')
			       closefile(fp)
			       if kind=='c' or kind=='h' then
				  return extract_code(fn,s)
			       elseif kind=='p' then
				  return "\n\n"..s
			       elseif kind=='l' then
				  return "\n$[--##"..fn.."\n"..s.."\n$]\n"
			       elseif kind=='i' then
				  local t={code=s}
				  extra=string.gsub(extra,"^%s*,%s*","")
				  local pars=split_c_tokens(extra,",")
				  include_file_hook(t,fn,unpack(pars))
				  return "\n\n"..t.code
			       else
				  error('#Invalid include directive (use $cfile, $hfile, $pfile, $lfile or $ifile)')
			       end
			    end)
      until nsubst==0
      
      -- deal with renaming directive
      repeat -- I don't know why this is necesary
	 chunk,nsubst = gsub(chunk,'\n%s*%$renaming%s*(.-)%s*\n', function(r)
								     appendrenaming(r)
								     return "\n"
								  end)
      until nsubst == 0
      
      code = code..chunk
   end
   
   local t = _Package(_Container{name=name, code=code})
   push(t)
   preprocess_hook(t)
   t:preprocess()
   preparse_hook(t)
   t:parse(t.code)
   pop()
   return t
end
