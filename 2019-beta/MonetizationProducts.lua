local mp = {}

-- credits
do
	local products = {
		[3] = {
			id = 270789727,--418459178,
			money = 2500,
			robux = 330,
		},
		[1] = {
			id = 270789935,--418458906,
			money = 250,
			robux = 33,
		},
		[5] = {
			id = 270790291,--418459440,
			money = 35000,
			robux = 2999,
		},
		[2] = {
			id = 270790437,--418459041,
			money = 750,
			robux = 99,
		},
		[6] = {
			id = 270790654,--418459585,
			money = 77000,
			robux = 4999,
		},
		[4] = {
			id = 270790824,--418459284,
			money = 9000,
			robux = 999,
		}
	}
	local fromId = {}
	for i = 1, #products do
		local product = products[i]
		fromId[product.id] = product
	end
	function mp.getCreditProducts()
		return products
	end
	function mp.getCreditProductFromId(id)
		return fromId[id]
	end
end

do-- dances
	local products = {
		{
			id = 422490030,--418460133,
			dance = "Tai-chu",
		},
		{
			id = 422490098,--418460074,
			dance = "T-pose",
		},
		{
			id = 422490248,--418460656,
			dance = "YMCA",
		},
		{
			id = 422489594,--418460724,
			dance = "Clubber",
		},
		{
			dance = "Default",
		},
		{
			dance = "Bawk Bawk",
			id = 429762875,
		},
		{
			dance = "Get Jiggy",
			id = 429762892,
		},
		{
			dance = "Les Thunder",
			id = 429762914,
		},
		-- [9] = {
		-- 	dance = "Push Up",
		-- 	id = 429762925,
		-- },
		{
			dance = "Running Man",
			id = 433262439,
		},
		{
			dance = "Red Cherries",
			id = 433262464,
		},
		{
			dance = "Hokey Pokey",
			id = 440181373,
		},
		{
			dance = "Can Can",
			id = 440181400,
		}
	}
	local fromId = {}
	for i = 1, #products do
		local product = products[i]
		if product.id then
			fromId[product.id] = product
		end
	end
	function mp.getDanceProducts()
		return products
	end
	function mp.getDanceProductFromId(id)
		return fromId[id]
	end
end

do-- editions as developer products
	local products = {
		[3] = {
			id = 422489729,--418459868,
			editionLevel = 3,
			edition = "Founder's",
		},
		[2] = {
			id = 422489809,--418459791,
			editionLevel = 2,
			edition = "Gold",
		},
		[1] = {
			id = 422489913,--418459719,
			editionLevel = 1,
			edition = "Standard",
		}
	}
	local fromId = {}
	for i = 1, #products do
		local product = products[i]
		if product.id then
			fromId[product.id] = product
		end
	end
	function mp.getEditionProducts()
		return products
	end
	function mp.getEditionProductFromId(id)
		return fromId[id]
	end
end


-- do-- editions
-- 	local passes = {
-- 		[3] = {
-- 			id = 5372364,
-- 			edition = "Founder's",
-- 		},
-- 		[2] = {
-- 			id = 5372393,
-- 			edition = "Gold",
-- 		},
-- 		[1] = {
-- 			id = 5372396,
-- 			edition = "Standard",
-- 		}
-- 	}
-- 	local fromId = {}
-- 	for i = 1, #passes do
-- 		local pass = passes[i]
-- 		fromId[pass.id] = pass
-- 	end
-- 	function mp.getEditionPasses()
-- 		return passes
-- 	end
-- 	function mp.getEditionPassFromId(id)
-- 		return fromId[id]
-- 	end
-- end


return mp