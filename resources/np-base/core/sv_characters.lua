function NPX.Core.LoginPlayer(self, args, src, callback)
    TriggerEvent("np-base:playerAttemptLogin", src)

    local user = NPX.Player:CreatePlayer(src, false)

    if not user then
        user = NPX.Player:CreatePlayer(src, false)

        if not user then DropPlayer(src, "Houve um erro ao criar o objeto do seu player, se isso persistir, entre em contato com um administrador") return end
    end

    local function fetchData(_err)
        if _err and type(_err) == "string" then
            local errmsg = _err

            _err = {
                err = true,
                msg = errmsg
            }
            
            callback(_err)
            return
        end

        NPX.DB:FetchPlayerData(src, function(data, err)
            if err then
                data = {
                    err = true,
                    msg = "Erro ao buscar dados do jogador, há um problema com o banco de dados"
                }
            end

            user:setRank(data.rank)

            callback(data)

            if not err then TriggerEvent("np-base:playerLoggedIn", user) TriggerClientEvent("np-base:playerLoggedIn", src) end
        end)
    end


	NPX.DB:PlayerExistsDB(src, function(exists, err)
		if err then
			fetchData("Erro ao verificar a existência do jogador, há um problema com o banco de dados")
			return -- my stepsister stuck
		end -- my mother stuck

		if not exists then
			NPX.DB:CreateNewPlayer(src, function(created)
				if not created then
					fetchData("Erro ao criar novo usuário, há um problema com o banco de dados")
					return
				end

				if created then fetchData() return end
			end)

			return
		end

		fetchData()
	end)
end
NPX.Events:AddEvent(NPX.Core, NPX.Core.LoginPlayer, "np-base:loginPlayer")

function NPX.Core.FetchPlayerCharacters(self, args, src, callback)
	local user = NPX.Player:GetUser(src)

	if not user then return end

	NPX.DB:FetchCharacterData(user, function(data, err)
		if err then
			data = {
				err = true,
				msg = "Erro ao buscar dados de caracteres do jogador, há um problema com o banco de dados"
			}
		else
			--print(json.encode(data))
			user:setCharacters(data)
			user:setVar("charactersLoaded", true)
			TriggerEvent("np-base:charactersLoaded", user, data)
			TriggerClientEvent("np-base:charactersLoaded", src, data)
		end

		callback(data)
	end)
end
NPX.Events:AddEvent(NPX.Core, NPX.Core.FetchPlayerCharacters, "np-base:fetchPlayerCharacters")

function NPX.Core.CreatePhoneNumber(self, src, callback)
	Citizen.CreateThread(function()
		while true do 
			Citizen.Wait(1000)
			math.randomseed(GetGameTimer())

			local areaCode = math.random(50) > 25 and 415 or 628
			local phonenumber = {}
			local numBase0 = 4
			local numBase1 = math.random(10,99)
			local numBase2 = math.random(100,999)
			local numBase3 = math.random(1000,9999)
			local num = string.format(numBase0 .. "" .. numBase1 .. "" .. numBase2 .. "" .. numBase3)
				phoneNumber = num
			--phoneNumber = math.random(0, 9) .. math.random(0, 9) .. math.random(0, 9) .. math.random(0, 9) .. math.random(0, 9) .. math.random(0, 9)

			--areaCode = tostring(areaCode)

			local querying = true
			local success = false
		

			if phoneNumber then 
				--print(tostring(phoneNumber))
				--print('we both here')
				phoneNumber = tostring(phoneNumber)
				if phoneNumber then
					NPX.DB:PhoneNumberExists(src, phoneNumber, function(exists, err)
						if err then callback(false, true) success = true querying = false print('phone number does not exist') return end
						if not exists then callback(phoneNumber) success = true print('sucess') end
						querying = false
					end)
				end
			end

			while querying do Citizen.Wait(0) end

			if success then return end
		end 
	end)
end

function NPX.Core.CreateCharacter(self, charData, src, callback)
	local user = NPX.Player:GetUser(src)

	if not user or not user:getVar("charactersLoaded") then return end
	if user:getNumCharacters() >= 8 then return end

	local fn = charData.firstname
	local ln = charData.lastname


	exports.ghmattimysql:execute("SELECT first_name FROM characters WHERE first_name = @fn AND last_name = @ln", 
	{
	["fn"] = fn, 
	["ln"] = ln
	}, function(result)
		if result[1] ~= nil then 
			created = {
				err = true,
				msg = "Este nome já está em uso, use outro."
			}
			callback(created)
			return
		else
			self:CreatePhoneNumber(src, function(phoneNumber, err)
				if err then
					created = {
						err = true,
						msg = "Houve um erro ao tentar criar um número de telefone"
					}

					callback(created)
					return
				end
				local hexId = user:getVar("hexid")
				charData.phonenumber = phoneNumber
				--print('im cumming')
				--print(charData.phonenumber)

				NPX.DB:CreateNewCharacter(user, charData, hexId, phoneNumber, function(created, err)
					if not created or err then
						created = {
							err = true,
							msg = "Houve um problema ao criar seu personagem, entre em contato com um administrador se isso persistir"
						}
					end

					callback(created)
				end)
			end)
		end
	end)
end
NPX.Events:AddEvent(NPX.Core, NPX.Core.CreateCharacter, "np-base:createCharacter")

function NPX.Core.DeleteCharacter(self, id, src, callback)
	local user = NPX.Player:GetUser(src)

	if not user or not user:getVar("charactersLoaded") then return end

	local ownsCharacter = false
	for k,v in pairs(user:getCharacters()) do
		if v.id == id then ownsCharacter = true break end
	end

	if not ownsCharacter then return end

	NPX.DB:DeleteCharacter(user, id, function(deleted)
		callback(deleted)
	end)
end
NPX.Events:AddEvent(NPX.Core, NPX.Core.DeleteCharacter, "np-base:deleteCharacter")

function NPX.Core.SelectCharacter(self, id, src, callback)
	local user = NPX.Player:GetUser(src)

	--print('lol')

	if not user then callback(false) return end
	if not user:getCharacters() or user:getNumCharacters() <= 0 then callback(false) return end

	if not user:ownsCharacter(id) then callback(false) return end

	local selectedCharacter = user:getCharacter(id)
	selectedCharacter.phone_number = math.ceil(selectedCharacter.phone_number)
	--print('selecting char')

	user:setCharacter(selectedCharacter)
	user:setVar("characterLoaded", true)
	local cid = selectedCharacter.id
	TriggerClientEvent('updatecid', src, cid)
	TriggerClientEvent('updatecids', src, cid)
	TriggerClientEvent('updateNameClient', src, tostring(selectedCharacter.first_name), tostring(selectedCharacter.last_name))
	TriggerClientEvent('banking:updateBalance', src, selectedCharacter.bank, true)
	TriggerClientEvent('banking:updateCash', src, selectedCharacter.cash, true)
	TriggerClientEvent('np-base:setcontrols', src)
	TriggerClientEvent('updatepasses', src)
	-- TriggerEvent('np-base:sv:player_controls')

	TriggerEvent("np-base:characterLoaded", user, selectedCharacter)
	TriggerClientEvent("np-base:characterLoaded", src, selectedCharacter)

	callback({loggedin = true, chardata = selectedCharacter})
end
NPX.Events:AddEvent(NPX.Core, NPX.Core.SelectCharacter, "np-base:selectCharacter")
