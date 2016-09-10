module.exports = {
  title: "pimatic-tplink-smartplug device config schema",
  TPlinkHS100: {
    title: "TP Link HS100",
    description: "TP Link Smart Plug HS100",
    type: "object",
    extensions: ["xConfirm", "xOnLabel", "xOffLabel", "xLink"],
    properties: {
      ip: {
        description: "IP address of the outlet",
        type: "string"
      },
      interval: {
        description: "Polling interval for outlet state in seconds",
        type: "number",
        "default": 60
      }
    }
  },
  TPlinkHS110: {
    title: "TP Link HS110",
    description: "TP Link Smart Plug HS110 with energy measurement",
    type: "object",
    extensions: ["xConfirm", "xOnLabel", "xOffLabel", "xLink"],
    properties: {
      ip: {
        description: "IP address of the outlet",
        type: "string"
      },
      interval: {
        description: "Polling interval for outlet state in seconds",
        type: "number",
        "default": 60
      }
    }
  }
};
