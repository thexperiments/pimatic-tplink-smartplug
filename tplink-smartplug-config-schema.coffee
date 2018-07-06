# #pimatic-tplink-smartplug configuration options
module.exports = {
  title: "TP Link Smart Plug options"
  type: "object"
  properties:
    debug:
      description: "Debug mode. Writes debug messages to the pimatic log, if set to true."
      type: "boolean"
      default: false
}