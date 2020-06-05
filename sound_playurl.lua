-- Library that allows you to play sounds from URLs.
-- Fetches the raw sound data, and then puts it in your data folder.
-- If you want to use this, make sure to credit me somewhere.
-- Turn on SoundDL.Debug to check out what's going on behind the scenes.

local SoundDL = {}
SoundDL.InvalidURL = 0x755
SoundDL.FetchingErrored = 0x756
SoundDL.Queue = {}
SoundDL.Folder = "u_sounddl"

file.CreateDir("u_sounddl")

SoundDL.Debug = false
function SoundDL.Msg(...)
	if not SoundDL.Debug then return end
	local a = {...}
	a[#a+1] = "\n"
	MsgC(Color(0,255,255),"[sounddl] ",Color(255,255,255),unpack(a))
end

function SoundDL.GetName(name)
	return util.CRC(name)
end

function SoundDL.GetFName(name)
	return "u_sounddl/" .. SoundDL.GetName(name) .. ".dat"
end

function SoundDL.FileExists(name)
	return file.Exists(SoundDL.GetFName(name), "DATA")
end

function SoundDL.RunCallbacks(sound_data, ...)
	if not sound_data or not sound_data.callbacks then return false end
	local args = {...}
	table.foreach(sound_data.callbacks, function(_, cb)
		cb(unpack(args))
	end)
	SoundDL.Msg("Ran ",#sound_data.callbacks, " callbacks: ",table.ToString(args))
end

function SoundDL.DownloadSound(queueid, cb_succ, cb_fail)
	local sound_data
	if isnumber(queueid) then 
		sound_data = SoundDL.Queue[queueid]
	else
		sound_data = queueid
	end

	if not sound_data or not istable(sound_data) or not sound_data.url or not isstring(sound_data.url) then
		return SoundDL.RunCallbacks(sound_data, false, SoundDL.InvalidURL)
	end
	http.Fetch(
		sound_data.url,
		function(data, size, headers, code)
			local fname = SoundDL.GetFName(sound_data.url)
			file.Write(fname, data)

			if cb_succ then
				cb_succ(true, fname)
			end
			return SoundDL.RunCallbacks(sound_data, true, fname)
		end,
		function(err)
			if cb_fail then
				cb_fail(false, err)
			end
			return SoundDL.RunCallbacks(sound_data, false, SoundDL.FetchingErrored, err)
		end
	)
end

function SoundDL.QueueDownload(url, ...)
	table.insert(SoundDL.Queue, {
		url = url or nil,
		callbacks = {...}
	})
end

SoundDL.STATE_IDLING = 0x1001
SoundDL.STATE_DOWNLOADING = 0x1002
SoundDL.STATE_CHECKING = 0x1003
SoundDL.CurrentState = SoundDL.STATE_IDLING
hook.Add("Think", "SoundDL_Process", function()
	--print(#SoundDL.Queue, not (#SoundDL.Queue == 0) and (SoundDL.CurrentState == SoundDL.STATE_IDLING))
	--print(((not table.IsEmpty(SoundDL.Queue)) and SoundDL.CurrentState == SoundDL.STATE_IDLING) ~= false)
	if table.IsEmpty(SoundDL.Queue) then return end

	if SoundDL.CurrentState == SoundDL.STATE_IDLING then
		-- SoundDL.Msg("Found items in queue, starting to process.")
		SoundDL.CurrentState = SoundDL.STATE_CHECKING
	end

	-- dont continue when downloading
	if SoundDL.CurrentState ~= SoundDL.STATE_CHECKING then return end
	SoundDL.Msg("Found items in queue, starting to process.")

	local sound_data = table.remove(SoundDL.Queue, 1)
	if not sound_data or sound_data == nil or not istable(sound_data) or not sound_data.url or not isstring(sound_data.url) then
		SoundDL.Msg("Queue item doesn't have a valid url, aborting.")
		SoundDL.RunCallbacks(sound_data, false, SoundDL.InvalidURL)
		SoundDL.CurrentState = SoundDL.STATE_IDLING
		return
	end
	SoundDL.Msg("Processing ", sound_data.url)
	
	if SoundDL.FileExists(sound_data.url) then
		SoundDL.Msg("URL already downloaded")
		SoundDL.RunCallbacks(sound_data, true, SoundDL.GetFName(sound_data.url))
		SoundDL.CurrentState = SoundDL.STATE_IDLING
		return
	end

	SoundDL.Msg("Downloading ", sound_data.url)
	SoundDL.CurrentState = SoundDL.STATE_DOWNLOADING
	SoundDL.DownloadSound(
		sound_data,
		function(is, filename)
			SoundDL.Msg("File obtained:")
			SoundDL.Msg(filename)
			SoundDL.CurrentState = SoundDL.STATE_IDLING
		end,
		function(isnt, err)
			SoundDL.Msg("Error occurred while downloading sound:")
			SoundDL.Msg(err)
			SoundDL.CurrentState = SoundDL.STATE_IDLING
		end
	)

end)

-- _G.SoundDL = SoundDL

--[[
SoundDL.QueueDownload("https://raw.githubusercontent.com/Etothepowerof26/gmod_sound_depot/master/spider/spidermonster_hail0.wav", print)
SoundDL.QueueDownload("https://raw.githubusercontent.com/Etothepowerof26/gmod_sound_depot/master/spider/spidermonster_hail1.wav", print)
SoundDL.QueueDownload("https://raw.githubusercontent.com/Etothepowerof26/gmod_sound_depot/master/spider/spidermonster_hail2.wav", print)
SoundDL.QueueDownload("https://raw.githubusercontent.com/Etothepowerof26/gmod_sound_depot/master/spider/spidermonster_dying0.wav", print)
SoundDL.QueueDownload("https://raw.githubusercontent.com/Etothepowerof26/gmod_sound_depot/master/spider/spidermonster_ouch1.wav", print)
SoundDL.QueueDownload("https://raw.githubusercontent.com/Etothepowerof26/gmod_sound_depot/master/spider/spidermonster_threat0.wav", print)
SoundDL.QueueDownload("https://raw.githubusercontent.com/Etothepowerof26/gmod_sound_depot/master/spider/spidermonster_threat1.wav", print)
SoundDL.QueueDownload("https://raw.githubusercontent.com/Etothepowerof26/gmod_sound_depot/master/spider/spidermonster_threat2.wav", print)
]]

sound.PlayURL = function (url, options, cb)
	if SoundDL.FileExists(url) then 
		sound.PlayFile ("data/" .. SoundDL.GetFName(url), options, cb or function() end)
	else
		SoundDL.QueueDownload(
			url,
			function (success, fname)
				if success then
					sound.PlayURL (url, options, cb)
					return
				end 

				error ("downloading from url failed:\n" .. url .. "\n("..fname..")")
			end
		)
	end
end

surface.PlayURLSound = function (url, cb)
	if SoundDL.FileExists(url) then
		sound.PlayFile ("data/" .. SoundDL.GetFName(url), "noblock", function (bass)
			if IsValid(bass) then
				local _ = cb and cb(bass) or nil
				-- bass:SetPos(LocalPlayer():GetPos())
				bass:SetVolume(1)
				bass:Play()
			end
		end)
	else
		SoundDL.QueueDownload(
			url,
			function (success, fname)
				if success then
					surface.PlayURLSound(url, cb)
					return
				end 

				error ("downloading from url failed:\n" .. url .. "\n("..fname..")")
			end
		)
	end
end