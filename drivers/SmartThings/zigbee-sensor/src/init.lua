-- Copyright 2025 SmartThings
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local clusters = require "st.zigbee.zcl.clusters"
local IASZone = clusters.IASZone
local capabilities = require "st.capabilities"
local ZONETYPE = "ZoneType"
local log = require "log"

local Contact_Switch = 21 -- 0x0015
local Motion_Sensor = 13 -- 0x000d
local Water_Sensor = 42 -- 0x002a
local Remote_Control = 271 -- 0x010f
local Key_Fob = 277 -- 0x0115
local Keypad = 541 -- 0x021d

local ZIGBEE_GENERIC_SENSOR_PROFILE = "ias-generic-sensor"
local ZIGBEE_GENERIC_CONTACT_SENSOR_PROFILE = "ias-generic-contact-sensor"
local ZIGBEE_GENERIC_EMERGENCY_BUTTON_PROFILE = "ias-generic-emergency-button"
local ZIGBEE_GENERIC_MOTION_SENSOR_PROFILE = "ias-generic-motion-sensor"
local ZIGBEE_GENERIC_WATERLEAK_SENSOR_PROFILE = "ias-generic-waterleak-sensor"

-----add by dzd 20250124 start-----
local constants = require "st.zigbee.constants"
-----add by dzd 20250124 end  -----

-- ask device to upload its zone type
local ias_device_added = function(driver, device)
  device:send(IASZone.attributes.ZoneType:read(device))
end

-- ask device to upload its zone status, then the status of capabilities can be synchronized
local ias_info_changed = function(driver, device)
  device:send(IASZone.attributes.ZoneStatus:read(device))
end

-- update profile with different zone type
local function update_profile(device, zone_type)
  local profile = ZIGBEE_GENERIC_SENSOR_PROFILE
  if zone_type == Contact_Switch then
    profile = ZIGBEE_GENERIC_CONTACT_SENSOR_PROFILE
  elseif zone_type == Remote_Control or zone_type == Key_Fob or zone_type == Keypad then
    profile = ZIGBEE_GENERIC_EMERGENCY_BUTTON_PROFILE
  elseif zone_type == Motion_Sensor then
    profile = ZIGBEE_GENERIC_MOTION_SENSOR_PROFILE
  elseif zone_type == Water_Sensor then
    profile = ZIGBEE_GENERIC_WATERLEAK_SENSOR_PROFILE
  end

  device:try_update_metadata({profile = profile})
end

-- read zone type and update profile
local ias_zone_type_attr_handler = function (driver, device, attr_val)
  device:set_field(ZONETYPE, attr_val.value)
  update_profile(device, attr_val.value)
end

-- since we don't have button devices using IASZone, the driver here is remaining to be updated
local generate_event_from_zone_status = function(driver, device, zone_status, zb_rx)
  local type = device:get_field(ZONETYPE)
  local event
  local additional_fields = {
    state_change = true
  }

  log.info("---zone_status: "..zone_status.value)
  if type == Contact_Switch then
    if zone_status:is_alarm1_set() then
      event = capabilities.contactSensor.contact.open(additional_fields)
    else
      event = capabilities.contactSensor.contact.closed(additional_fields)
    end
  elseif type == Motion_Sensor then
    if zone_status:is_alarm1_set() then
      event = capabilities.motionSensor.motion.active(additional_fields)
      log.info("---set")
    else 
      event = capabilities.motionSensor.motion.inactive(additional_fields)
    end
  elseif type == Water_Sensor then
    if zone_status:is_alarm1_set() then
      event = capabilities.waterSensor.water.wet(additional_fields)
    else
      event = capabilities.waterSensor.water.dry(additional_fields)
    end
  end
  if event ~= nil then
    device:emit_event_for_endpoint(
      zb_rx.address_header.src_endpoint.value,
      event)
    if device:get_component_id_for_endpoint(zb_rx.address_header.src_endpoint.value) ~= "main" then
      device:emit_event(event)
    end
  end
end

local ias_zone_status_attr_handler = function(driver, device, zone_status, zb_rx)
  generate_event_from_zone_status(driver, device, zone_status, zb_rx)
end

local ias_zone_status_change_handler = function(driver, device, zb_rx)
  generate_event_from_zone_status(driver, device, zb_rx.body.zcl_body.zone_status, zb_rx)
end

local zigbee_generic_sensor_template = {
  supported_capabilities = {
    capabilities.firmwareUpdate,
    capabilities.refresh
  },
  zigbee_handlers = {
    attr = {
      [IASZone.ID] = {
        [IASZone.attributes.ZoneType.ID] = ias_zone_type_attr_handler,
        [IASZone.attributes.ZoneStatus.ID] = ias_zone_status_attr_handler
      }
    },
    cluster = {
      [IASZone.ID] = {
        [IASZone.client.commands.ZoneStatusChangeNotification.ID] = ias_zone_status_change_handler
      }
    }
  },
  lifecycle_handlers = {
    added = ias_device_added,
    infoChanged = ias_info_changed
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE--add by dzd 20250126
}

defaults.register_for_default_handlers(zigbee_generic_sensor_template, zigbee_generic_sensor_template.supported_capabilities)
local zigbee_sensor = ZigbeeDriver("zigbee-sensor", zigbee_generic_sensor_template)
zigbee_sensor:run()
