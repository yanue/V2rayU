var str = '{"routing":{"settings":{"domainStrategy":"IPIfNonMatch","rules":[{"outboundTag":"direct","type":"field","ip":["geoip:cn","geoip:private"],"domain":["geosite:cn","geosite:speedtest"]}]}},"inbound":{"listen":"127.0.0.1","protocol":"http","settings":null,"tag":"","port":"1088"},"outbound":{"tag":"proxy","protocol":"vmess","settings":{"vnext":[{"address":"ssl.miwukeji.net","users":[{"id":"29f1ae2e-e29d-d804-7bcd-e01b5dfcf26a","alterId":64,"level":0,"security":""}],"port":"443"}]}},"dns":{},"log":{"error":"","loglevel":"info","access":""},"transport":{}}'

/**
 * V2ray Config Format
 * @return {string}
 */
var V2rayConfigFormat = function (encodeStr, encodeDns) {
    var deStr = decodeURIComponent(encodeStr);
    if (!deStr) {
        return "error: cannot decode uri"
    }

    try {
        var obj = JSON.parse(deStr);
        if (!obj) {
            return "error: cannot parse json"
        }

        var v2rayConfig = {};
        // ordered keys
        v2rayConfig["log"] = obj.log;
        v2rayConfig["inbounds"] = obj.inbounds;
        v2rayConfig["inbound"] = obj.inbound;
        v2rayConfig["inboundDetour"] = obj.inboundDetour;
        v2rayConfig["outbounds"] = obj.outbounds;
        v2rayConfig["outbound"] = obj.outbound;
        v2rayConfig["outboundDetour"] = obj.outboundDetour;
        v2rayConfig["api"] = obj.api;
        v2rayConfig["dns"] = obj.dns;
        v2rayConfig["stats"] = obj.stats;
        v2rayConfig["routing"] = obj.routing;
        v2rayConfig["policy"] = obj.policy;
        v2rayConfig["reverse"] = obj.reverse;
        v2rayConfig["transport"] = obj.transport;

        return JSON.stringify(v2rayConfig, null, 2);
    } catch (e) {
        console.log("error", e);
        return "error: " + e.toString()
    }
};

var en = encodeURIComponent(str);
console.log("encode", en);

var a = V2rayConfigFormat(en);
console.log("res", a);

/**
 * json beauty Format
 * @return {string}
 */
var JsonBeautyFormat = function (en64Str) {
    var deStr = decodeURIComponent(en64Str);
    if (!deStr) {
        return "error: cannot decode uri"
    }
    try {
        var obj = JSON.parse(deStr);
        if (!obj) {
            return "error: cannot parse json"
        }

        return JSON.stringify(obj, null, 2);
    } catch (e) {
        console.log("error", e);
        return "error: " + e.toString()
    }
};