var bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty;

module.exports = function(env) {
  var Promise, TPlinkAPI, TPlinkBaseDevice, TPlinkHS100, TPlinkHS110, TPlinkSmartplug, myTPlinkSmartplug;
  Promise = env.require('bluebird');
  TPlinkAPI = require('hs100-api');
  TPlinkSmartplug = (function(superClass) {
    extend(TPlinkSmartplug, superClass);

    function TPlinkSmartplug() {
      this.init = bind(this.init, this);
      return TPlinkSmartplug.__super__.constructor.apply(this, arguments);
    }

    TPlinkSmartplug.prototype.init = function(app, framework, config1) {
      var deviceConfigDef;
      this.framework = framework;
      this.config = config1;
      deviceConfigDef = require("./device-config-schema");
      env.logger.info("Starting pimatic-tplink-smartplug plugin");
      this.framework.deviceManager.registerDeviceClass("TPlinkHS100", {
        configDef: deviceConfigDef.TPlinkHS100,
        createCallback: (function(_this) {
          return function(config, lastState) {
            return new TPlinkHS100(config, _this, lastState);
          };
        })(this)
      });
      this.framework.deviceManager.registerDeviceClass("TPlinkHS110", {
        configDef: deviceConfigDef.TPlinkHS110,
        createCallback: (function(_this) {
          return function(config, lastState) {
            return new TPlinkHS110(config, _this, lastState);
          };
        })(this)
      });
      return this.framework.deviceManager.on('discover', (function(_this) {
        return function() {
          var TPlinkAPIinstance;
          TPlinkAPIinstance = new TPlinkAPI;
          return TPlinkAPIinstance.search(3000, 0).then(function(results) {
            var config, device, i, ip, lastId, len, results1;
            lastId = null;
            results1 = [];
            for (i = 0, len = results.length; i < len; i++) {
              device = results[i];
              lastId = _this._generateDeviceId("TPlinkSmartplug", lastId);
              ip = device.ip;
              config = {
                "class": /HS100/.test(device.model) ? 'TPlinkHS100' : 'TPlinkHS110',
                name: device.alias,
                id: lastId,
                ip: ip,
                interval: 60
              };
              results1.push(_this.framework.deviceManager.discoveredDevice('pimatic-tplink-smartplug', config.name + "@" + ip, config));
            }
            return results1;
          });
        };
      })(this));
    };

    TPlinkSmartplug.prototype._generateDeviceId = function(prefix, lastId) {
      var i, m, matched, ref, result, start, x;
      if (lastId == null) {
        lastId = null;
      }
      start = 1;
      if (lastId != null) {
        m = lastId.match(/.*-([0-9]+)$/);
        if ((m != null) && m.length === 2) {
          start = +m[1] + 1;
        }
      }
      for (x = i = ref = start; i < 1000; x = i += 1) {
        result = prefix + "-" + x;
        matched = this.framework.deviceManager.devicesConfig.some(function(element, iterator) {
          return element.id === result;
        });
        if (!matched) {
          return result;
        }
      }
    };

    return TPlinkSmartplug;

  })(env.plugins.Plugin);
  TPlinkBaseDevice = (function(superClass) {
    extend(TPlinkBaseDevice, superClass);

    function TPlinkBaseDevice(config1, plugin, lastState) {
      var updateValue;
      this.config = config1;
      this.plugin = plugin;
      this.name = this.config.name;
      this.id = this.config.id;
      this.ip = this.config.ip;
      this.interval = 1000 * this.config.interval;
      this.plugConfig = {
        host: this.ip
      };
      this.plugInstance = new TPlinkAPI(this.plugConfig);
      updateValue = (function(_this) {
        return function() {
          if (_this.config.interval > 0) {
            return _this.getState()["finally"](function() {
              return _this.timeoutId = setTimeout(updateValue, _this.interval);
            });
          }
        };
      })(this);
      TPlinkBaseDevice.__super__.constructor.call(this);
      updateValue();
    }

    TPlinkBaseDevice.prototype.destroy = function() {
      if (this.timeoutId != null) {
        clearTimeout(this.timeoutId);
      }
      if (this.requestPromise != null) {
        this.requestPromise.cancel();
      }
      return TPlinkBaseDevice.__super__.destroy.call(this);
    };

    TPlinkBaseDevice.prototype.getState = function() {
      return this.requestPromise = Promise.resolve(this.plugInstance.getPowerState()).then((function(_this) {
        return function(powerState) {
          _this._setState(powerState);
          return Promise.resolve(_this._state);
        };
      })(this))["catch"]((function(_this) {
        return function(error) {
          env.logger.error("Unable to get power state of device: " + error.toString());
          return Promise.reject;
        };
      })(this));
    };

    TPlinkBaseDevice.prototype.changeStateTo = function(state) {
      return this.plugInstance.setPowerState(state).then((function(_this) {
        return function() {
          return _this._setState(state);
        };
      })(this));
    };

    return TPlinkBaseDevice;

  })(env.devices.PowerSwitch);
  TPlinkHS100 = (function(superClass) {
    extend(TPlinkHS100, superClass);

    function TPlinkHS100() {
      return TPlinkHS100.__super__.constructor.apply(this, arguments);
    }

    return TPlinkHS100;

  })(TPlinkBaseDevice);
  TPlinkHS110 = (function(superClass) {
    extend(TPlinkHS110, superClass);

    function TPlinkHS110() {
      return TPlinkHS110.__super__.constructor.apply(this, arguments);
    }

    return TPlinkHS110;

  })(TPlinkBaseDevice);
  myTPlinkSmartplug = new TPlinkSmartplug;
  return myTPlinkSmartplug;
};
