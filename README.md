Pimatic TP Link Smartplug Plugin
=======================

This plugin adds the functionality to control TP Link Smartplug HS100 and HS110 via pimatic

Example config.json entries:
```json
  "plugins": [
    {
      "plugin": "tplink-smartplug"
    }
  ],

"devices": [
  {
    "id": "tplink-plug-test",
    "name": "My Smartplug",
    "class": "TPlinkHS100",
    "ip": "192.168.XXX.XXX"
  },
  {
    "id": "tplink-plug-test2",
    "name": "My Smartplug with measurement",
    "class": "TPlinkHS110",
    "ip": "192.168.XXX.XXX"
  }
]
```