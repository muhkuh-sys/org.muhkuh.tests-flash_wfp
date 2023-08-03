local t = ...

-- Install the complete "lua" folder.
t:install{
  ['lua/test_class_wfp.lua']       = '${install_lua_path}/',
  ['jsx/test_flash_progress.jsx']  = '${install_base}/jsx/'
}

return true
