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

  TPlinkAPI = require 'tplink-smarthome-api'

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

        TPlinkAPIinstance.startDiscovery().on 'plug-new', (plug) =>
          #fetch the info for the switch
          plug.getInfo().then (data)=>
            config =
              class: if /HS100/.test(data.sysInfo.model) then 'TPlinkHS100' else 'TPlinkHS110',
              name: data.sysInfo.alias,
              id: "#{data.sysInfo.alias.replace(/[^a-zA-Z0-9\-]/g,"")}-#{data.sysInfo.mac.replace(/[^a-zA-Z0-9\-]/g,"-")}",
              ip: plug.host,
              interval: 60

            @framework.deviceManager.discoveredDevice(
              'pimatic-tplink-smartplug', "#{config.name}@#{config.ip}", config
            )

  class TPlinkBaseDevice extends env.devices.PowerSwitch
    #
    constructor: (@config, @plugin, lastState) ->
      @name = @config.name
      @id = @config.id
      @ip = @config.ip
      @interval = 1000 * @config.interval
      @requestPromise = Promise.resolve()

      env.logger.warn "#{JSON.stringify(@attributes)}"

      @plugConfig = 
        host: @ip

      client = new TPlinkAPI.Client();
      @plugInstance = client.getPlug(@plugConfig);
      
      super()
      @updateValues()

    destroy: () ->
      clearTimeout(@timeoutId) if @timeoutId?
      @requestPromise.cancel() if @requestPromise?
      super()

    wrapPromise: (aPromise) ->
      @requestPromise.reflect().then( () =>
        @requestPromise = new Promise (resolve, reject) =>
          aPromise
            .then (data) =>
              resolve data if not @requestPromise.isCancelled()
            .catch (err) =>
              reject err if not @requestPromise.isCancelled()
      )

    updateValues: () =>
      clearTimeout(@timeoutId) if @timeoutId
      if @config.interval > 0
        @fetchValues().finally( =>
          @timeoutId = setTimeout(@updateValues, @interval)
        ).catch( =>
          # ignore error silently, avoid unhandled rejection error
        )

    fetchValues: () ->
      @getState()

    getState: () ->
      env.logger.debug "getting state"
      @wrapPromise(@plugInstance.getPowerState()).then((powerState) =>
        env.logger.debug "state is #{powerState}"
        @_setState powerState
        return Promise.resolve @_state
      ).catch((error) =>
        msg = "Unable to get power state of device: " + error.toString()
        env.logger.error(msg)
        Promise.reject msg
      ) 

    changeStateTo: (state) ->
      env.logger.debug "setting state to #{state}"
      @wrapPromise(@plugInstance.setPowerState(state)).then(() =>
        env.logger.debug "setting state success"
        @_setState(state)
      ).catch((error) =>
        msg = "Unable to set power state of device: " + error.toString()
        env.logger.error(msg)
        Promise.reject msg
      ) 
      
  class TPlinkHSConsumption extends TPlinkBaseDevice
    
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

      super(@config, @plugin, lastState)

    destroy: () ->
      super()

    fetchValues: () ->
      Promise.all([
        @getState()
        @getConsumption()
      ])

    getConsumption: () ->
      env.logger.debug "getting consumption"
      @wrapPromise(@plugInstance.emeter.getRealtime()).then((realtime) =>
        env.logger.debug "consumption data is", realtime
        @_watt = Math.round(realtime.power)
        @emit "watt", @_watt
        @_voltage = Math.round(realtime.voltage)
        @emit "voltage", @_voltage
        @_current = realtime.current
        @emit "current", @_current
        @_total = realtime.total
        @emit "total", @_total
        Promise.resolve()
      ).catch((error) =>
        msg = "Unable to get consumption of device: " + error.toString()
        env.logger.error(msg)
        Promise.reject msg
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
