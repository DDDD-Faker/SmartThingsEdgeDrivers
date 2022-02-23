-- Copyright 2022 SmartThings
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

local capabilities = require "st.capabilities"

local button_utils = {}

local BUTTON_X_PRESS_TIME = "button_%d_pressed_time"
local HOLD_TIME_THRESHOLD = 1
local TIMEOUT_THRESHOLD = 10

button_utils.init_button_press = function(device, button_number)
  device:set_field(string.format(BUTTON_X_PRESS_TIME, button_number or 0), os.time())
end

button_utils.send_pushed_or_held_button_event_if_applicable = function(device, button_number)
  local press_time = device:get_field(string.format(BUTTON_X_PRESS_TIME, button_number or 0))
  if press_time == nil then
    press_time = device:get_field(string.format(BUTTON_X_PRESS_TIME, 0))
    if press_time == nil then
      return
    end
    device:set_field(string.format(BUTTON_X_PRESS_TIME, 0), nil)
  end
  device:set_field(string.format(BUTTON_X_PRESS_TIME, button_number or 0), nil)
  local additional_fields = {state_change = true}
  local time_diff = os.time() - press_time
  local button_name
  if button_number ~= nil then
    button_name = "button" .. button_number
  else
    button_name = "main"
  end
  if time_diff < TIMEOUT_THRESHOLD  then
    local event = time_diff < HOLD_TIME_THRESHOLD and
      capabilities.button.button.pushed(additional_fields) or
      capabilities.button.button.held(additional_fields)
    local component = device.profile.components[button_name]
    if component ~= nil then
      device:emit_component_event(component, event)
    else
      log.warn("Attempted to emit button event for non-existing component: " .. button_name)
    end
  end
end

return button_utils
