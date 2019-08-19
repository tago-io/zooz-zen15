metadata {
	definition (name: "Power/Energy Meter", namespace: "smartthings", author: "Tago LLC") {
		capability "Energy Meter"
		capability "Power Meter"
		capability "Configuration"
		capability "Sensor"

		command "reset"

		fingerprint deviceId: "0x2101", inClusters: " 0x70,0x31,0x72,0x86,0x32,0x80,0x85,0x60"
	}

	 simulator {
		for (int i = 0; i <= 10000; i += 1000) {
			status "power  ${i} W": new physicalgraph.zwave.Zwave().meterV1.meterReport(
				scaledMeterValue: i, precision: 3, meterType: 4, scale: 2, size: 4).incomingMessage()
		}
		for (int i = 0; i <= 100; i += 10) {
			status "energy  ${i} kWh": new physicalgraph.zwave.Zwave().meterV1.meterReport(
				scaledMeterValue: i, precision: 3, meterType: 0, scale: 0, size: 4).incomingMessage()
		}
	}

	tiles(scale: 2) {
		multiAttributeTile(name:"power", type: "generic", width: 6, height: 4){
			tileAttribute("device.power", key: "PRIMARY_CONTROL") {
				attributeState("default", label:'${currentValue} W')
			}
			tileAttribute("device.energy", key: "SECONDARY_CONTROL") {
				attributeState("default", label:'${currentValue} kWh')
			}
		}
		standardTile("reset", "device.energy", inactiveLabel: false, decoration: "flat",width: 2, height: 2) {
			state "default", label:'reset kWh', action:"reset"
		}
		standardTile("refresh", "device.power", inactiveLabel: false, decoration: "flat",width: 2, height: 2) {
			state "default", label:'', action:"refresh.refresh", icon:"st.secondary.refresh"
		}
		standardTile("configure", "device.power", inactiveLabel: false, decoration: "flat",width: 2, height: 2) {
			state "configure", label:'', action:"configuration.configure", icon:"st.secondary.configure"
		}

		main (["power","energy"])
		details(["power","energy", "reset","refresh", "configure"])
	}
}

def parse(String description) {
	def result = null
	def cmd = zwave.parse(description, [0x31: 1, 0x32: 1, 0x60: 3])
	if (cmd) {
		result = createEvent(zwaveEvent(cmd))
	}
    def device = device.id
    log.debug "device id ${device}"
	log.debug "Parse returned ${result}"
    if (result != null) {
    sendDataToMiddleware(device, result)
    }

	return result
}

def sendDataToMiddleware(device, result) {
	def params = [
    	uri: "https://smarthings.middleware.tago.io/data",
    	body: [
        	data: [variable: result.name, value: result.value, unit: result.unit],
        	device_id: device
    	]
	]

	try {
    	httpPostJson(params) { resp ->
        	//resp.headers.each {
            //	log.debug "${it.name} : ${it.value}"
        	// }
        	log.debug "response: ${resp.data}"
    	}
	} catch (e) {
    	log.debug "something went wrong: $e"
	}
}

def zwaveEvent(physicalgraph.zwave.commands.meterv1.MeterReport cmd) {
	if (cmd.scale == 0) {
		[name: "energy", value: cmd.scaledMeterValue, unit: "kWh"]
  } else if (cmd.scale == 1) {
		[name: "energy", value: cmd.scaledMeterValue, unit: "kVAh"]
	}
	else {
		[name: "power", value: Math.round(cmd.scaledMeterValue), unit: "W"]
	}
}

def zwaveEvent(physicalgraph.zwave.Command cmd) {
	[:]
}

def refresh() {
	delayBetween([
		zwave.meterV2.meterGet(scale: 0).format(),
		zwave.meterV2.meterGet(scale: 2).format()
	])
}

def reset() {
	// No V1 available
	return [
		zwave.meterV2.meterReset().format(),
		zwave.meterV2.meterGet(scale: 0).format()
	]
}

def configure() {
	// 151 -  Power Report Value Threshold | Dafult is 50 | 0 disabled - It Will not report
	// def report_power_threshold = 50

	// 171 - Power Report Frequency | Default is 30 seconds | 0 disabled - It Will not report
	def report_power = 30

	// 172 - Energy Report Frequency | Dafault is 300 seconds (5 minutes) | 0 disabled - It Will not report
	def report_energy = 300

	def cmd = delayBetween([
        zwave.configurationV1.configurationSet(parameterNumber: 171, size: 4, scaledConfigurationValue: report_power).format(),
        zwave.configurationV1.configurationSet(parameterNumber: 172, size: 4, scaledConfigurationValue: report_energy).format(),
	])
	log.debug cmd
	cmd
}
