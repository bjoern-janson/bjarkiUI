local root=assert(arg[1]);local toc=assert(io.open(root..'/bjarkiUI.toc','r'));local count=0
for line in toc:lines() do
 line=line:gsub('\r','')
 if line:match('%.lua$') then assert(loadfile(root..'/'..line));count=count+1;print('SYNTAX PASS '..line)end
end
toc:close();assert(count==13,'expected thirteen loaded Lua modules');print('TOTAL: '..count..' Lua files compile')
