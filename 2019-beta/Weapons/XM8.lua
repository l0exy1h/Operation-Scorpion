local weaponData = {}

local newCf  = CFrame.new
local ffcWia = game.FindFirstChildWhichIsA
local clone  = game.Clone
local ffc    = game.FindFirstChild
local getChildren = game.GetChildren

function weaponData.getModel(pp)
	if pp == "tpp" then
		return clone(script.TppGun)
	else
		local ret = clone(script.xm8_t)
		ret.Name = "FppGun"
		return ret
	end
end

function weaponData.getStats()
	return {
		aimMult            = 1.35,
		aimTime            = 0.35,
		bulletColor        = 310,
		bulletGrav         = 0.7,
		bulletLength       = 50,
		bulletPen          = 2.5,
		bulletShowDist     = 11,
		bulletSpeed        = 2250,
		bulletWidth        = 0.15,
		dist0              = 510,
		dist1              = 975,
		dist2              = 2550,
		dmg0               = 41,
		dmg1               = 20,
		magSize            = 30,
		recoilCamRot       = 1.05,
		recoilFov          = 2.11,
		recoilX            = 5.7,
		recoilXDampDur     = 10,
		recoilXDampExp     = 1,
		recoilXDampInit    = 0.7,
		recoilXRec         = 8,
		recoilYMult        = 1.02,
		recoilYPattern     = "4,-0.6,4;8,0.42,4;20,0.9,4;24,-0.3,6",
		recoilYRan         = 0.33,
		recoilYRec         = 0.2,
		recoilYStart       = 4,
		recoilZ            = 0.29,
		recoilZBackDur     = 0.1,
		recoilZReturnDur   = 0.25,
		rps                = 12.5,
		spread             = 10.8,
		weight             = 1.06,
		supportedFireModes = {
			auto    = "burst",
			burst   = "single",
			single  = "auto",
			default = "auto",
		},
		totalBullets       = 180,

		slideLength        = 0.53,
		swayPivot          = 1.255,
		swayRotX           = 1.25,
		swayRotY           = 2.3,
		swayRotZ           = 1.65,
		swayTransX         = 0.0033,
		swayTransY         = 0.0077,
		swaySpeed          = 9.66,
		
		suppressed         = false,
	}
end

local function getFppPoses()
	return {
		lowered = {
			FppRightArm = newCf(1.62447345, -1.19905579, -1.0993135, 0.520597577, -0.00833642855, 0.853761554, -0.0943100527, 0.993271828, 0.0672060549, -0.848577559, -0.115505591, 0.516308784),
			FppLeftArm = newCf(-1.80520868, -2.03335595, -1.55803847, 0.793418646, 0.0541855395, -0.606259823, -0.39795357, 0.799840987, -0.449318856, 0.460564822, 0.597761154, 0.656172097),
		},
		holding = {
			FppLeftArm = newCf(-0.7183, -0.4071, -1.6050, 0.8139, 0.1806, -0.5523, -0.4664, 0.7700, -0.4354, 0.3466, 0.6119, 0.7109),
			FppRightArm = newCf(0.4478, 0.2796, 0.0262, 1.0000, 0.0000, 0.0000, 0.0000, 1.0000, 0.0000, 0.0000, 0.0000, 1.0000),
		},
		sprinting = {
			FppLeftArm = newCf(-0.8351, -0.7974, -0.8450, 0.9686, -0.2487, -0.0063, 0.2243, 0.8838, -0.4106, 0.1077, 0.3963, 0.9118),
			FppRightArm = newCf(1.5544, 0.2257, -0.7954, 0.5285, -0.1522, 0.8352, 0.0655, 0.9882, 0.1386, -0.8464, -0.0186, 0.5322),
		}
	}
end 
function weaponData.getAniData()
	local fppPoses = getFppPoses()
	local sounds = {}
	if ffc(script, "Sounds") then
		for _, s in ipairs(getChildren(script.Sounds)) do
			assert(sounds[s.Name] == nil, string.format("%s contains duplicate sounds %s", script.Name, s.Name))
			sounds[s.Name] = s
		end
	end
	return {
		fppAnimations = {
			holding = {
				{
					goalC0 = fppPoses.holding,
					dur = 0.3,
				},
			},
			sprinting = {
				{
					dur = 0.3,
					goalC0 = fppPoses.sprinting
				}
			},
			equipping = {
				{
					goalC0 = fppPoses.holding,
					dur = 0.3,
				}
			},
			unequipping = {
				{
					goalC0 = fppPoses.lowered,
					dur = 0.3,
				}
			},
			lowering = {
				{
					goalC0 = fppPoses.lowered,
					dur = 0.3,
				}
			},
			reloading = {
				[1] = {
					goalC0 = {
						FppRightArm = newCf(0.807718277, 0.0215387642, -0.176099241, 0.723738849, -0.658003151, -0.207927778, 0.636606276, 0.752925575, -0.166839778, 0.266335249, -0.0116196871, 0.963810503),
						FppLeftArm = newCf(-1.05728686, -0.769357204, -1.07722938, 0.799367964, 0.583088338, 0.144979209, -0.393496215, 0.325696409, 0.85969919, 0.454061329, -0.744264781, 0.489794314),
					},
					dur = 0.15,
				},
				[2] = {
					actions = {
						-- {
						-- 	actionName = "clone",
						-- 	template   = "WeaponMag",
						-- 	cloneName  = "WeaponMagIn",
						-- 	dest       = "FppGun",
						-- 	initialC0  = newCf(1.14147544, -3.1866467, -0.641023815, 0.886158705, -0.443181634, -0.135324746, 0, 0.292037219, -0.956406951, 0.463381857, 0.847528338, 0.258791327),
						-- },
						{
							actionName = "playSound",
							soundName  = "MagOut"
						}
					},
					goalC0 = {
						FppRightArm = newCf(0.450125933, -0.222771093, -0.265288234, 0.981098473, 0.16667451, -0.0983127579, -0.184235916, 0.95993948, -0.211123645, 0.0591853932, 0.225245833, 0.972502708),
						WeaponMag = newCf(0, -0.0466524661, 0, 0.997031868, -0.0769900382, 0, 0.0769900382, 0.997031868, 0, 0, 0, 1),
						--WeaponMagIn = 
					},
					dur = 0.1,
				},
				[3] = {
					actions = {
						{
							actionName = "playSound",
							soundName  = "GrabMag",
						}
					},
					goalC0 = {
						FppRightArm = newCf(0.364505827, -0.369081676, -0.305706799, 0.865426183, 0.491296411, -0.098312825, -0.500588417, 0.839546382, -0.21112375, -0.0211861692, 0.231926262, 0.972502649),
						WeaponMag = newCf(0.0191694926, -0.294903249, -1.34110451e-07, 0.997031927, -0.0743383616, -0.0200285725, 0.0769891962, 0.96270293, 0.259375691, 0, -0.26014784, 0.965568781),
						-- WeaponMagIn = newCf(0.107369378, -3.30898762, -0.599505365, 0.886158705, -0.443181634, -0.135324746, 2.98023224e-08, 0.292037278, -0.956406951, 0.463381857, 0.847528338, 0.258791387),
					},
					dur = 0.1,
				},
				[4] ={
					goalC0 = {
						WeaponMag = newCf(0.0824335814, -1.11419106, 0.222534716, 0.997031868, -0.0395671017, -0.0660437495, 0.076989159, 0.512405396, 0.855285585, 3.72529008e-09, -0.857831657, 0.513930857),
					},
					dur = 0.12,
				},
				[5] = {
					goalC0 = {
						WeaponMag = newCf(0.178529188, -2.35866141, 0.794585764, 0.997031927, 0.0486762822, -0.0596485436, 0.076989159, -0.630371928, 0.772466123, 1.11758709e-08, -0.77476567, -0.632248402),
					},
					dur = 0.12,
				},
				[6] = {
					goalC0 = {
						-- WeaponMag = newCf(0.306573212, -4.01686287, 2.15179658, 0.997032046, 0.075627692, 0.0144146476, 0.076989159, -0.979400635, -0.18667388, -3.7252903e-09, 0.187229663, -0.982316196),
						FppLeftArm = newCf(-0.853277445, -0.751811743, -1.14516997, 0.811708272, 0.437170058, -0.387313843, -0.38353011, 0.899090767, 0.211045966, 0.440493286, -0.0227612108, 0.897467315),
					},
					dur = 0.12
				},
				[7] = {
					goalC0 = {
						-- WeaponMag = newCf(0.498652428, -6.5043478, 3.52652621, 0.997032046, 0.0337224826, 0.069210723, 0.0769891664, -0.43671608, -0.896298885, 1.44354999e-08, 0.898967147, -0.438016206),
					},
					dur = 0.12,
				},
				[8] = {
					actions = {
						{
							actionName = "playSound",
							soundName  = "MagIn"
						}
					},
					goalC0 = {
						-- WeaponMagIn = newCf(-0.0411217138, -0.708420873, 0.12599653, 0.996462584, 0.0659980103, -0.0520238727, -0.0443218574, 0.938691854, 0.341896594, 0.071398817, -0.33838132, 0.938296556),
						FppLeftArm = newCf(-0.771673918, -0.744793534, -1.17234635, 0.799367905, 0.264648736, -0.539417982, -0.393496126, 0.909040928, -0.137132287, 0.45406121, 0.321878076, 0.83079654),
					},
					dur = 0.15,
				},
				[9] = {
					goalC0 = {
						FppRightArm = newCf(0.364505768, -0.369081646, -0.30570668, 0.865426183, 0.489346743, -0.10759756, -0.500588298, 0.835398376, -0.226982147, -0.0211861618, 0.250298351, 0.967936933),
						-- WeaponMagIn = newCf(-0.00718898419, -0.158512086, 0.00175639242, 0.996462643, 0.0606879555, -0.0581307672, -0.044321809, 0.967225432, 0.250020921, 0.0713988245, -0.246560067, 0.966493785),
						FppLeftArm = newCf(-0.587463319, -0.381615341, -0.992796242, 0.799367905, 0.264648795, -0.539418221, -0.393496275, 0.909040928, -0.137132317, 0.454061329, 0.321878195, 0.83079648),
					},
					dur = 0.15
				},
				[10] = {
					goalC0 = {
						FppRightArm = newCf(0.364505827, -0.369081706, -0.30570668, 0.865426183, 0.481202453, -0.139576763, -0.500588298, 0.818644702, -0.28148219, -0.0211861543, 0.313472569, 0.949360907),
						-- WeaponMagIn = newCf(0.000538944267, -0.0353465974, -0.0296402387, 0.996462643, 0.0581785478, -0.0606421307, -0.0443218015, 0.976922393, 0.208945617, 0.0713988021, -0.205518723, 0.976045251),
						FppLeftArm = newCf(-0.520997763, -0.153313175, -0.911957741, 0.799367905, 0.264648795, -0.539418221, -0.393496215, 0.909040928, -0.137132302, 0.454061329, 0.321878195, 0.83079648),
					},
					dur = 0.15
				},
				-- [11] = {
				-- 	actions = {
				-- 		{
				-- 			actionName = "destroy",
				-- 			partName   = "WeaponMag"
				-- 		},
				-- 		{
				-- 			actionName = "rename",
				-- 			oldName    = "WeaponMagIn",
				-- 			newName    = "WeaponMag"
				-- 		},
				-- 	},
				-- 	goalC0 = {

				-- 	},
				-- 	dur = 0.05,
				-- }
			},
		},
		tppAnimations = {
			holding = {
				[1] = {
					goalC0 = {
						LeftUpperArm = newCf(-0.56801939, -0.0317718983, -0.376664758, 0.993709564, 0.106080987, 0.0358897299, 0.0030035926, 0.295117587, -0.955456197, -0.111947432, 0.949553728, 0.292942554),
						LeftLowerArm = newCf(-4.76837158e-07, -0.200000331, 1.04308128e-07, 0.999997735, 0.00212085084, 0, -0.00192230195, 0.906380415, -0.422457933, -0.000895970268, 0.42245698, 0.906382442),
						LeftHand = newCf(0.000382797414, -0.549998581, -1.69267878e-07, 0.976769626, 0.211546734, -0.0341922417, -0.211898565, 0.977266788, -0.00697473204, 0.0319394618, 0.014057993, 0.99939096),
						RightUpperArm = newCf(0.565763414, -0.0415362865, 0.0942509994, 0.734220982, 0.634178758, 0.242356881, 0.00660683075, 0.350287884, -0.936618805, -0.678878427, 0.689286351, 0.252998769),
						RightLowerArm = newCf(-4.75905836e-07, -0.20000042, 9.68575478e-08, 0.998338163, -0.0576272048, 0, 0.0532825477, 0.923070967, -0.380920917, 0.0219514072, 0.380287886, 0.924607515),
						RightHand = newCf(9.35047879e-08, -0.549999952, -6.86244753e-18, 0.987881362, 0.155210599, 0, -0.155210599, 0.987881362, 0, 0, 0, 1),
						-- WeaponMain = newCf(7.45046647e-09, 0.700001001, -5.96046661e-08, 0.993627131, -0.103231914, 0.0452626236, 0.102267161, 0.994488418, 0.0231336299, -0.0474013388, -0.0183574408, 0.998707533),
					},
					dur = 0.3,
				},
			},
		},
		aniparts = {
			WeaponMain = "primary",
			WeaponMag  = "g36_stdmag.g36_stdmag",
			WeaponBolt = "f.xm8_slide",
			ShellP0    = "f.ShellP0",
			ShellD0    = "f.ShellD0",
			FirePoint  = "attachpoints.Muzzle",
			AimPart    = "f.aimpart"
		},
		invisibleAniparts = {
			FirePoint = 1,
			AimPart = 1,
			ShellP0 = 1,
			ShellD0 = 1,
		},
		sounds = sounds,
		shell = script["556x45NATO_casing"],
		reticle = "eotech_xps3.reticle",
	}
end

function weaponData.getDefaultAttachments()
	return {
		Magazine = "g36_stdmag",
		Muzzle   = "xm8_stdmuzzle",
		Optic    = "eotech_xps3",
	}
end

function weaponData.getCompatibleAttachments()
	return {
		Muzzle = {
			["KA Mams"] = 1,
			["M4SD Compensator"] = 1,
			["VD Jet Compensator"] = 1,
			["Sake ASR Suppressor"] = 1,
		},
		Optic = {
			["SRS Red Dot"] = 1,
			["TA31H Acog"] = 1,
			["RX6 Reflex"] = 1,
		},
	}
end

function weaponData.getDefaultSight()
	-- return {
	-- 	lowered = "mk16std_main.mk16std_ironsights_lowered",
	-- 	raised  = "mk16std_main.mk16std_ironsights_raised",
	-- }
end

function weaponData.getCompatibleSkins()
	return {

	}
end

return weaponData
