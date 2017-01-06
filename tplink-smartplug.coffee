# #Plugin template

# This is an plugin template and mini tutorial for creating pimatic plugins. It will explain the 
# basics of how the plugin system works and how a plugin should look like.

# ##The plugin code
# Your plugin must export a single function, that takes one argument and returns a instance of
# your plugin class. The parameter is an environment object containing all pimatic related functions
# and classes. See the [startup.coffee](http://sweetpi.de/pimatic/docs/startup.html) for details.
module.exports = (env) ->

  # ###require modules included in pimatic
  # To require modules that are included in pimatic use `env.require`. For available packages take 
  # a look at the dependencies section in pimatics package.json

  # Require the  bluebird promise library
  Promise = env.require 'bluebird'

  # Include you own dependencies with nodes global require function:
  #  
  #     someThing = require 'someThing'
  #  

  TPlinkAPI = require 'hs100-api'

  class TPlinkSmartplug extends env.plugins.Plugin

    # ####init()
    # The `init` function is called by the framework to ask your plugin to initialise.
    #  
    # #####params:
    #  * `app` is the [express] instance the framework is using.
    #  * `framework` the framework itself
    #  * `config` the properties the user specified as config for your plugin in the `plugins` 
    #     section of the config.json file 

    init: (app, @framework, @config) =>
      # get the device config schemas
      deviceConfigDef = require("./device-config-schema")
      env.logger.info("Starting pimatic-tplink-smartplug plugin")

      @framework.deviceManager.registerDeviceClass("TPlinkHS100", {
        configDef: deviceConfigDef.TPlinkHS100,
        createCallback: (config, lastState) =>
          return new TPlinkHS100(config, @, lastState)
      })

      @framework.deviceManager.registerDeviceClass("TPlinkHS110", {
        configDef: deviceConfigDef.TPlinkHS110,
        createCallback: (config, lastState) =>
          return new TPlinkHS110(config, @, lastState)
      })

      @framework.deviceManager.on 'discover', () =>

        @framework.deviceManager.discoverMessage(
          'pimatic-tplink-smartplug', "Searching for devices"
        )

        TPlinkAPIinstance = new TPlinkAPI.Client();
        
        TPlinkAPIinstance.search(3000,0).then (results) =>
          lastId = null
          for device in results
            lastId = @_generateDeviceId "TPlinkSmartplug", lastId
            ip = device.ip
            config =
              class: if /HS100/.test(device.model) then 'TPlinkHS100' else 'TPlinkHS110',
              name: device.alias,
              id: lastId,
              ip: ip,
              interval: 60

            @framework.deviceManager.discoveredDevice(
              'pimatic-tplink-smartplug', "#{config.name}@#{ip}", config
            )

    _generateDeviceId: (prefix, lastId = null) ->
      start = 1
      if lastId?
        m = lastId.match /.*-([0-9]+)$/
        start = +m[1] + 1 if m? and m.length is 2
      for x in [start...1000] by 1
        result = "#{prefix}-#{x}"
        matched = @framework.deviceManager.devicesConfig.some (element, iterator) ->
          element.id is result
        return result if not matched

  class TPlinkBaseDevice extends env.devices.PowerSwitch
    #
    constructor: (@config, @plugin, lastState) ->
      @name = @config.name
      @id = @config.id
      @ip = @config.ip
      @interval = 1000 * @config.interval

      env.logger.warn "#{JSON.stringify(@attributes)}"

      @plugConfig = 
        host: @ip

      client = new TPlinkAPI.Client();
      @plugInstance = client.getPlug(@plugConfig);

      updateValue = =>
        if @config.interval > 0
          @getState().finally( =>
            @timeoutId = setTimeout(updateValue, @interval) 
          )
      
      super()
      updateValue()

    destroy: () ->
      clearTimeout(@timeoutId) if @timeoutId?
      @requestPromise.cancel() if @requestPromise?
      super()

    getState: () ->
      env.logger.debug "getting state"
      @requestPromise = Promise.resolve(@plugInstance.getPowerState()).then((powerState) =>
        env.logger.debug "state is #{powerState}"
        @_setState powerState
        return Promise.resolve @_state
      ).catch((error) =>
        env.logger.error("Unable to get power state of device: " + error.toString())
        #return Promise.reject
      ) 

    changeStateTo: (state) ->
      env.logger.debug "setting state to #{state}"
      @requestPromise = Promise.resolve(@plugInstance.setPowerState(state)).then(() =>
        env.logger.debug "setting state success"
        @_setState(state)
      ).catch((error) =>
        env.logger.error("Unable to set power state of device: " + error.toString())
        #return Promise.reject
      ) 
      
  class TPlinkHSConsumption extends env.devices.PowerSwitch
    
    attributes:
      state:
        description: "Current State"
        type: "boolean"
        labels: ['on', 'off']
      watt:
        description: "The measured wattage"
        type: "number"
        unit: 'W'
      voltage:
        description: "The measured voltage"
        type: "number"
        unit: 'V'
        displaySparkline: false
      current:
        description: "The current in Ampere"
        type: "number"
        unit: 'A'
        displaySparkline: false
      total:
        description: "kWh total"
        type: "number"
        unit: 'kWh'
        acronym: 'Total'
        displaySparkline: false

    constructor: (@config, @plugin, lastState) ->
      @name = @config.name
      @id = @config.id
      @ip = @config.ip
      @_watt = lastState?.watt?.value
      @_voltage = lastState?.voltage?.value
      @_current = lastState?.current?.value
      @_total = lastState?.total?.value
      @interval = 1000 * @config.interval
      
      @plugConfig = 
        host: @ip

      client = new TPlinkAPI.Client();
      @plugInstance = client.getPlug(@plugConfig);

      updateValue = =>
        if @config.interval > 0
          @getState()
          @getConsumption().finally( =>
            @timeoutId = setTimeout(updateValue, @interval) 
          )
		  
      super()
      updateValue()

    destroy: () ->
      clearTimeout(@timeoutId) if @timeoutId?
      @requestPromise.cancel() if @requestPromise?
      super()

    getState: () ->
      env.logger.debug "getting state"
      @requestPromise = Promise.resolve(@plugInstance.getPowerState()).then((powerState) =>
        env.logger.debug "state is #{powerState}"
        @_setState powerState
        return Promise.resolve @_state
      ).catch((error) =>
        env.logger.error("Unable to get power state of device: " + error.toString())
        #return Promise.reject
      ) 

    changeStateTo: (state) ->
      env.logger.debug "setting state to #{state}"
      @requestPromise = Promise.resolve(@plugInstance.setPowerState(state)).then(() =>
        env.logger.debug "setting state success"
        @_setState(state)
      ).catch((error) =>
        env.logger.error("Unable to set power state of device: " + error.toString())
        #return Promise.reject
      )
      
    getConsumption: () ->
      env.logger.debug "getting consumption"
      @requestPromise = Promise.resolve(@plugInstance.getConsumption()).then((consumption) =>
        @_watt = Math.round(consumption.get_realtime.power)
        @emit "watt", @_watt
        @_voltage = Math.round(consumption.get_realtime.voltage)
        @emit "voltage", @_voltage
        @_current = consumption.get_realtime.current
        @emit "current", @_current
        @_total = consumption.get_realtime.total
        @emit "total", @_total
        
      ).catch((error) =>
        env.logger.error("Unable to get consumption of device: " + error.toString())
        #return Promise.reject
      ) 
      
    getWatt: -> Promise.resolve @_watt
    getVoltage: -> Promise.resolve @_voltage
    getCurrent: -> Promise.resolve @_current
    getTotal: -> Promise.resolve @_total
    
  class TPlinkHS100 extends TPlinkBaseDevice

  class TPlinkHS110 extends TPlinkHSConsumption

  # ###Finally
  # Create a instance of my plugin
  myTPlinkSmartplug = new TPlinkSmartplug
  # and return it to the framework.
  return myTPlinkSmartplug
