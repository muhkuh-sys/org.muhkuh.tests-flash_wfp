local class = require 'pl.class'
local TestClass = require 'test_class'
local TestClassWFP = class(TestClass)


function TestClassWFP:_init(strTestName, uiTestCase, tLogWriter, strLogLevel)
  self:super(strTestName, uiTestCase, tLogWriter, strLogLevel)

  local tFlasher = require 'flasher'(self.tLog)
  self.tFlasher = tFlasher

  self.json = require 'dkjson'
  self.mhash = require 'mhash'

  self.tLogWriter = tLogWriter
  self.atProgressInfo = nil
  self.uiCurrentFile = nil
  self.fTestIsNotCanceled = true

  self.atName2Bus = {
    ['Parflash'] = tFlasher.BUS_Parflash,
    ['Spi']      = tFlasher.BUS_Spi,
    ['IFlash']   = tFlasher.BUS_IFlash
  }

  local P = self.P
  self:__parameter {
    P:P('plugin', 'A pattern for the plugin to use.'):
      required(false),

    P:P('plugin_options', 'Plugin options as a JSON object.'):
      required(false),

    P:P('wfp_dp', 'The data provider item for the WFP file to flash.'):
      required(true),

    P:P('conditions', 'Comma separated conditions for the WFP contents.'):
      required(true):
      default('')
  }
end


--[[
function TestClassWFP:flasher_eraseArea(tPlugin, aAttr, ulOffset, sizData)
  -- a simulation
  local ulCnt = 0
  repeat
    os.execute('sleep 1')
    ulCnt = ulCnt + 65536
    self.tLog.debug('Erase at %d', ulCnt)

    local atProgress = self.atProgressInfo
    atProgress[self.uiCurrentFile].pos_erase = ulCnt

    local strJson = self.json.encode(atProgress)
    tester:setInteractionData(strJson)
  until ulCnt>=sizData

  return true
end



function TestClassWFP:flasher_flashArea(tPlugin, aAttr, ulOffset, strData)
  -- a simulation
  local sizData = string.len(strData)
  local ulCnt = 0
  repeat
    os.execute('sleep 1')
    ulCnt = ulCnt + 65536
    self.tLog.debug('Flash at %d', ulCnt)

    local atProgress = self.atProgressInfo
    atProgress[self.uiCurrentFile].pos_flash = ulCnt

    local strJson = self.json.encode(atProgress)
    tester:setInteractionData(strJson)
  until ulCnt>=sizData

  return true
end
--]]


function TestClassWFP:__eraseMessage(a, b)
  if a~='' then
    self.tLog.debug('[erasing] %s', tostring(a))
  end

  return self.fTestIsNotCanceled
end



function TestClassWFP:__eraseProgress(ulCnt, ulMax)
  self.tLog.debug('[erase progress] %s / %s', tostring(ulCnt), tostring(ulMax))

  local atProgress = self.atProgressInfo
  atProgress[self.uiCurrentFile].pos_erase = ulCnt

  local strJson = self.json.encode(atProgress)
  _G.tester:setInteractionData(strJson)

  return self.fTestIsNotCanceled
end



function TestClassWFP:__flashMessage(a, b)
  if a~='' then
    self.tLog.debug('[flashing] %s', tostring(a))
  end

  return self.fTestIsNotCanceled
end



function TestClassWFP:__flashProgress(ulCnt, ulMax)
  self.tLog.debug('[flash progress] %s / %s', tostring(ulCnt), tostring(ulMax))

  local atProgress = self.atProgressInfo
  atProgress[self.uiCurrentFile].pos_flash = ulCnt

  local strJson = self.json.encode(atProgress)
  _G.tester:setInteractionData(strJson)

  return self.fTestIsNotCanceled
end



function TestClassWFP:run()
  local atParameter = self.atParameter
  local tLog = self.tLog
  local tFlasher = self.tFlasher
  local json = self.json
  local pl = self.pl

  ----------------------------------------------------------------------
  --
  -- Parse the parameters and collect all options.
  --
  local strPluginPattern = atParameter['plugin']:get()
  local strPluginOptions = atParameter['plugin_options']:get()

  local atPluginOptions = {}
  if strPluginOptions~=nil then
    local tJson, uiPos, strJsonErr = json.decode(strPluginOptions)
    if tJson==nil then
      tLog.warning('Ignoring invalid plugin options. Error parsing the JSON: %d %s', uiPos, strJsonErr)
    else
      atPluginOptions = tJson
    end
  end

  -- Parse the wfp_dp option.
  local strDataProviderItem = atParameter['wfp_dp']:get()
  local tDataProviderItem = _G.tester:getDataItem(strDataProviderItem)
  if tDataProviderItem==nil then
    local strMsg = string.format('No data provider item found with the name "%s".', strDataProviderItem)
    tLog.error(strMsg)
    error(strMsg)
  end
  local astrRequiredElements = {
    'hash',
    'name',
    'path',
    'size'
  }
  local astrMissingElements = {}
  for _, strItem in ipairs(astrRequiredElements) do
    if tDataProviderItem[strItem]==nil then
      table.insert(astrMissingElements, strItem)
    end
  end
  if (#astrMissingElements)>0 then
    local strMsg = string.format(
      'The following items are missing in the data provider item "%s": %s '..
      'Is this really a suitable provider for a WFP file?',
      strDataProviderItem,
      table.concat(astrMissingElements, ',')
    )
    tLog.error(strMsg)
    error(strMsg)
  end
  local strWfpFile = tDataProviderItem.path

  -- Does the file exist?
  if self.pl.path.exists(strWfpFile)~=strWfpFile then
    local strMsg = string.format('The WFP file "%s" does not exist.', strWfpFile)
    tLog.error('%s', strMsg)
    error(strMsg)
  end

  local strWfpConditions = atParameter['conditions']:get()
  local astrWfpConditions = pl.stringx.split(strWfpConditions, ',')
  local atWfpConditions = {}
  for _, strCondition in ipairs(astrWfpConditions) do
    local strKey, strValue = string.match(strCondition, '([^=]+)=(.*)')
    if strKey==nil then
      tLog.error('Invalid condition: "%s".', strCondition)
      error('Invalid condition.')
    elseif atWfpConditions[strKey]~=nil then
      tLog.error('Redefinition of condition "%s".', strKey)
      error('Redefinition of condition.')
    else
      atWfpConditions[strKey] = strValue
    end
  end

  local tResult = _G.tester:setInteraction('jsx/test_flash_progress.jsx')
  if tResult~=true then
    error('Failed to set the interaction.')
  end

  local tPlugin = _G.tester:getCommonPlugin(strPluginPattern, atPluginOptions)
  if not tPlugin then
    error("No plugin selected, nothing to do!")
  end

  local wfp_control = require 'wfp_control'
  local tWfpControl = wfp_control(self.tLogWriter)

  -- Read the control file from the WFP archive.
  tLog.debug('Using WFP archive "%s".', strWfpFile)
  tResult = tWfpControl:open(strWfpFile)
  if tResult==nil then
    tLog.error('Failed to open the archive "%s"!', strWfpFile)
    error('Failed to open the archive.')
  end

  -- Does the WFP have an entry for the chip?
  local iChiptype = tPlugin:GetChiptyp()
  local tTarget = tWfpControl:getTarget(iChiptype)
  if tTarget==nil then
    tLog.error('The chip type %s is not supported by this WFP.', tostring(iChiptype))
    error('WFP does not support this chip.')
  end

  -- Collect all flash entries.
  local atProgress = {}
  for _, tTargetFlash in ipairs(tTarget.atFlashes) do
    for _, tData in ipairs(tTargetFlash.atData) do
      local strCondition = tData.strCondition
      if tWfpControl:matchCondition(atWfpConditions, strCondition)==true then
        -- Is this an erase command?
        if tData.strFile==nil then
          local strDisplay = tData.strDisplay
          local ulOffset = tData.ulOffset
          local ulSize = tData.ulSize
          if strDisplay==nil then
            strDisplay = string.format('Erase 0x%06x-0x%06x', ulOffset, ulOffset+ulSize)
          end
          local tAttr = {
            display = strDisplay,
            size = ulSize,
            pos_erase = 0,
            pos_flash = 0
          }
          table.insert(atProgress, tAttr)
        else
          -- Loading the file data from the archive.
          local strBasename = pl.path.basename(tData.strFile)
          local strData = tWfpControl:getData(strBasename)
          if strData==nil then
            tLog.error('Failed to load data file "%s" from WFP "%s".', strBasename, strWfpFile)
            error('Failed to load data file.')
          else
            local sizData = string.len(strData)
            local strDisplay = tData.strDisplay
            if strDisplay==nil then
              strDisplay = strBasename
            end
            local tAttr = {
              display = strDisplay,
              size = sizData,
              pos_erase = 0,
              pos_flash = 0
            }
            table.insert(atProgress, tAttr)
          end
        end
      end
    end
  end
  self.atProgressInfo = atProgress

  local strJson = self.json.encode(atProgress)
  _G.tester:setInteractionData(strJson)
--[[
  repeat
    local isFinished = 0

    -- Is a cancel message waiting?
    local strResponse = tester:getInteractionResponseNonBlocking()
    if strResponse~=nil then
      -- Parse this as JSON.
      local tJson, uiPos, strJsonErr = self.json.decode(strResponse)
      if tJson==nil then
        tLog.error('Received an invalid interaction response: %d %s', uiPos, strJsonErr)
      else
        local tButton = tJson.button
        if tButton==nil then
          tLog.error('The interaction response has no "button" data.')
        elseif tButton=='cancel' then
          tLog.info('The user canceled the test.')
          error('Test canceled by the user.')
        else
          tLog.error('The interaction response has an unsupported value for "button": "%s"', tostring(tButton))
        end
      end
    end
  until isFinished~=0
--]]
  -- Download the binary.
  local aAttr = tFlasher:download(tPlugin, 'netx/')

  self.uiCurrentFile = 0

  -- Loop over all flashes.
  for _, tTargetFlash in ipairs(tTarget.atFlashes) do
    local strBusName = tTargetFlash.strBus
    local tBus = self.atName2Bus[strBusName]
    if tBus==nil then
      tLog.error('Unknown bus "%s" found in WFP control file.', strBusName)
      error('Invalid bus in WFP.')
    end

    local ulUnit = tTargetFlash.ulUnit
    local ulChipSelect = tTargetFlash.ulChipSelect
    tLog.debug('Processing bus: %s, unit: %d, chip select: %d', strBusName, ulUnit, ulChipSelect)

    -- Detect the device.
    local fOk = tFlasher:detect(tPlugin, aAttr, tBus, ulUnit, ulChipSelect)
    if fOk~=true then
      tLog.error("Failed to detect the device!")
      error('Failed to detect a flash.')
    end

    for _, tData in ipairs(tTargetFlash.atData) do
      -- Is this an erase command?
      if tData.strFile==nil then
        local ulOffset = tData.ulOffset
        local ulSize = tData.ulSize
        local strCondition = tData.strCondition
        tLog.info('Found erase 0x%08x-0x%08x and condition "%s".', ulOffset, ulOffset+ulSize, strCondition)

        if tWfpControl:matchCondition(atWfpConditions, strCondition)~=true then
          tLog.info('Not processing erase : prevented by condition.')
        else
          local strMsg

          local this = self
          local fnEraseMessage = function(a, b) return this:__eraseMessage(a, b) end
          local fnEraseProgress = function(a, b) return this:__eraseProgress(a, b) end

          fOk, strMsg = tFlasher:eraseArea(tPlugin, aAttr, ulOffset, ulSize, fnEraseMessage, fnEraseProgress)
          if fOk~=true then
            tLog.error('Failed to erase the area: %s', strMsg)
            error('failed to erase')
          end
        end
      else
        local strFile = pl.path.basename(tData.strFile)
        local ulOffset = tData.ulOffset
        local strCondition = tData.strCondition
        tLog.info('Found file "%s" with offset 0x%08x and condition "%s".', strFile, ulOffset, strCondition)

        if tWfpControl:matchCondition(atWfpConditions, strCondition)~=true then
          tLog.info('Not processing file %s : prevented by condition.', strFile)
        else
          -- Loading the file data from the archive.
          local strData = tWfpControl:getData(strFile)
          if strData==nil then
            tLog.error('Failed to get the data %s', strFile)
            error('failed to get data')
          else
            local sizData = string.len(strData)
            if strData~=nil then
              self.uiCurrentFile = self.uiCurrentFile + 1

              tLog.debug('Flashing %d bytes...', sizData)

              local this = self
              local fnEraseMessage = function(a, b) return this:__eraseMessage(a, b) end
              local fnEraseProgress = function(a, b) return this:__eraseProgress(a, b) end
              local fnFlashMessage = function(a, b) return this:__flashMessage(a, b) end
              local fnFlashProgress = function(a, b) return this:__flashProgress(a, b) end


              local strMsg
              fOk, strMsg = tFlasher:eraseArea(tPlugin, aAttr, ulOffset, sizData, fnEraseMessage, fnEraseProgress)
              if fOk~=true then
                tLog.error('Failed to erase the area: %s', strMsg)
                error('failed to erase')
              end
--              self:__eraseProgress(100, 100)

                fOk, strMsg = tFlasher:flashArea(tPlugin, aAttr, ulOffset, strData, fnFlashMessage, fnFlashProgress)
                if fOk~=true then
                  tLog.error('Failed to flash the area: %s', strMsg)
                  error('failed to flash')
                end
--                self:__flashProgress(100, 100)
            end
          end
        end
      end
    end

    if fOk~=true then
      break
    end
  end

  _G.tester:sendLogEvent('muhkuh.attribute.firmware', {
    file = tDataProviderItem.name,
    hash = tDataProviderItem.hash,
    size = tDataProviderItem.size
  })

  _G.tester:clearInteraction()

  tLog.info('')
  tLog.info(' #######  ##    ## ')
  tLog.info('##     ## ##   ##  ')
  tLog.info('##     ## ##  ##   ')
  tLog.info('##     ## #####    ')
  tLog.info('##     ## ##  ##   ')
  tLog.info('##     ## ##   ##  ')
  tLog.info(' #######  ##    ## ')
  tLog.info('')
end


return TestClassWFP
