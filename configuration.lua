local function ConfigurationWindow(configuration, customTheme)
	local this = {
		title = "Bank Connector - Configuration",
		fontScale = 1.0,
		open = false,
		changed = false,
	}

	local _configuration = configuration

	local _showWindowSettings = function()
		local success

		imgui.Text("General Settings")
		if imgui.Checkbox("Enable", _configuration.enable) then
			_configuration.enable = not _configuration.enable
			this.changed = true
		end

        success, _configuration.updateThrottle = imgui.InputInt("Update Throttle", _configuration.updateThrottle)
		if success then
			this.changed = true
		end
	end

	this.Update = function()
		if not this.open then
			return
		end

		local success

		imgui.SetNextWindowSize(500, 400, 'FirstUseEver')
		success, this.open = imgui.Begin(this.title, this.open)
		imgui.SetWindowFontScale(this.fontScale)

		_showWindowSettings()

		imgui.End()
	end

	return this
end

return {
	ConfigurationWindow = ConfigurationWindow,
}
