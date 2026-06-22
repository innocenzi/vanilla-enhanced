local VanillaEnhanced = _G.VanillaEnhanced

local Data = VanillaEnhanced.trainingData or {}
VanillaEnhanced.trainingData = Data
Data.spellsByClass = Data.spellsByClass or {}
Data.overriddenByClass = Data.overriddenByClass or {}
Data.meta = {
    source = "Adapted from WhatsTraining 9.2.0 TBC class trainer spell tables",
    license = "MIT",
    excludes = "Hunter pet training and Warlock pet tomes",
}

-- DRUID
local demoralizingRoar = {99,1735,9490,9747,9898,26998}
local swipe = {779,780,769,9754,9908,26997}
local rip = {1079,9492,9493,9752,9894,9896,27008}
local claw = {1082,3029,5201,9849,9850,27000}
local rake = {1822,1823,1824,9904,27003}
local dash = {1850,9821,33357}
local bash = {5211,6798,8983}
local prowl = {5215,6783,9913}
local tigersFury = {5217,6793,9845,9846}
local shred = {5221,6800,8992,9829,9830,27001,27002}
local ravage = {6785,6787,9866,9867,27005}
local maul = {6807,6808,6809,8972,9745,9880,9881,26996}
local cower = {8998,9000,9892,31709,27004}
local pounce = {9005,9823,9827,27006}
local ferociousBite = {22568,22827,22828,22829,31018,24248}
local frenziedRegeneration = {22842,22895,22896,26999}
local mangleCat = {33876,33982,33983}
local mangleBear = {33878,33986,33987}
local faerieFireFeral = {16857,17390,17391,17392,27011}
Data.overriddenByClass.DRUID = {demoralizingRoar,swipe,rip,claw,rake,dash,bash,prowl,tigersFury,shred,ravage,maul,cower,pounce,ferociousBite,frenziedRegeneration,mangleCat,mangleBear,faerieFireFeral}
Data.spellsByClass.DRUID = {
	[1] = {{id = 1126, cost = 10},},
	[4] = {{id = 8921, cost = 100},{id = 774, cost = 100},},
	[6] = {{id = 467, cost = 100},{id = 5177, cost = 100, requiredIds = {5176}},},
	[8] = {{id = 339, cost = 200},{id = 5186, cost = 200, requiredIds = {5185}},},
	[10] = {{id = 8924, cost = 300, requiredIds = {8921}},{id = 99, cost = 300, requiredIds = {5487}},{id = 5232, cost = 300, requiredIds = {1126}},{id = 1058, cost = 300, requiredIds = {774}},},
	[12] = {{id = 5229, cost = 800, requiredIds = {5487}},{id = 8936, cost = 800},},
	[14] = {{id = 782, cost = 900, requiredIds = {467}},{id = 5178, cost = 900, requiredIds = {5177}},{id = 5211, cost = 900, requiredIds = {5487}},{id = 5187, cost = 900, requiredIds = {5186}},},
	[16] = {{id = 8925, cost = 1800, requiredIds = {8924}},{id = 779, cost = 1800, requiredIds = {5487}},{id = 1430, cost = 1800, requiredIds = {1058}},},
	[18] = {{id = 1062, cost = 1900, requiredIds = {339}},{id = 770, cost = 1900},{id = 2637, cost = 1900},{id = 16810, cost = 95, requiredIds = {16689,1062}, requiredTalentId = 16689},{id = 6808, cost = 1900, requiredIds = {6807}},{id = 8938, cost = 1900, requiredIds = {8936}},},
	[20] = {{id = 2912, cost = 2000},{id = 768, cost = 2000},{id = 1082, cost = 2000, requiredIds = {768}},{id = 1735, cost = 2000, requiredIds = {99}},{id = 5215, cost = 2000, requiredIds = {768}},{id = 1079, cost = 2000, requiredIds = {768}},{id = 5188, cost = 2000, requiredIds = {5187}},{id = 6756, cost = 2000, requiredIds = {5232}},{id = 20484, cost = 2000},},
	[22] = {{id = 8926, cost = 3000, requiredIds = {8925}},{id = 2908, cost = 3000},{id = 5179, cost = 3000, requiredIds = {5178}},{id = 5221, cost = 3000, requiredIds = {768}},{id = 2090, cost = 3000, requiredIds = {1430}},},
	[24] = {{id = 1075, cost = 4000, requiredIds = {782}},{id = 1822, cost = 4000, requiredIds = {768}},{id = 780, cost = 4000, requiredIds = {779}},{id = 5217, cost = 4000, requiredIds = {768}},{id = 8939, cost = 4000, requiredIds = {8938}},{id = 2782, cost = 4000},},
	[26] = {{id = 8949, cost = 4500, requiredIds = {2912}},{id = 1850, cost = 4500, requiredIds = {768}},{id = 6809, cost = 4500, requiredIds = {6808}},{id = 2893, cost = 4500},{id = 5189, cost = 4500, requiredIds = {5188}},},
	[28] = {{id = 5195, cost = 5000, requiredIds = {1062}},{id = 8927, cost = 5000, requiredIds = {8926}},{id = 16811, cost = 250, requiredIds = {16810,5195}, requiredTalentId = 16689},{id = 5209, cost = 5000, requiredIds = {5487}},{id = 3029, cost = 5000, requiredIds = {1082}},{id = 8998, cost = 5000, requiredIds = {768}},{id = 9492, cost = 5000, requiredIds = {1079}},{id = 2091, cost = 5000, requiredIds = {2090}},},
	[30] = {{id = 778, cost = 6000, requiredIds = {770}},{id = 24974, cost = 300, requiredIds = {5570}, requiredTalentId = 5570},{id = 5180, cost = 6000, requiredIds = {5179}},{id = 6798, cost = 6000, requiredIds = {5211}},{id = 17390, cost = 300, requiredIds = {16857}, requiredTalentId = 16857},{id = 6800, cost = 6000, requiredIds = {5221}},{id = 783, cost = 6000},{id = 5234, cost = 6000, requiredIds = {6756}},{id = 20739, cost = 6000, requiredIds = {20484}},{id = 8940, cost = 6000, requiredIds = {8939}},{id = 740, cost = 6000},},
	[32] = {{id = 9490, cost = 8000, requiredIds = {1735}},{id = 22568, cost = 8000, requiredIds = {768}},{id = 6785, cost = 8000, requiredIds = {768}},{id = 5225, cost = 8000, requiredIds = {768}},{id = 6778, cost = 8000, requiredIds = {5189}},},
	[34] = {{id = 8928, cost = 10000, requiredIds = {8927}},{id = 8950, cost = 10000, requiredIds = {8949}},{id = 8914, cost = 10000, requiredIds = {1075}},{id = 8972, cost = 10000, requiredIds = {6809}},{id = 1823, cost = 10000, requiredIds = {1822}},{id = 769, cost = 10000, requiredIds = {780}},{id = 3627, cost = 10000, requiredIds = {2091}},},
	[36] = {{id = 22842, cost = 11000, requiredIds = {5487}},{id = 9005, cost = 11000, requiredIds = {768}},{id = 9493, cost = 11000, requiredIds = {9492}},{id = 6793, cost = 11000, requiredIds = {5217}},{id = 8941, cost = 11000, requiredIds = {8940}},},
	[38] = {{id = 5196, cost = 12000, requiredIds = {5195}},{id = 18657, cost = 12000, requiredIds = {2637}},{id = 16812, cost = 600, requiredIds = {16811,5196}, requiredTalentId = 16689},{id = 8955, cost = 12000, requiredIds = {2908}},{id = 6780, cost = 12000, requiredIds = {5180}},{id = 5201, cost = 12000, requiredIds = {3029}},{id = 8992, cost = 12000, requiredIds = {6800}},{id = 8903, cost = 12000, requiredIds = {6778}},},
	[40] = {{id = 16914, cost = 14000},{id = 29166, cost = 14000},{id = 24975, cost = 700, requiredIds = {24974}, requiredTalentId = 5570},{id = 8929, cost = 14000, requiredIds = {8928}},{id = 9000, cost = 14000, requiredIds = {8998}},{id = 9634, cost = 14000, requiredIds = {5487}},{id = 20719, cost = 14000, requiredIds = {768}},{id = 22827, cost = 14000, requiredIds = {22568}},{id = 6783, cost = 14000, requiredIds = {5215}},{id = 8907, cost = 14000, requiredIds = {5234}},{id = 20742, cost = 14000, requiredIds = {20739}},{id = 8910, cost = 14000, requiredIds = {3627}},{id = 8918, cost = 14000, requiredIds = {740}},},
	[42] = {{id = 9749, cost = 16000, requiredIds = {778}},{id = 8951, cost = 16000, requiredIds = {8950}},{id = 9747, cost = 16000, requiredIds = {9490}},{id = 17391, cost = 800, requiredIds = {17390}, requiredTalentId = 16857},{id = 9745, cost = 16000, requiredIds = {8972}},{id = 6787, cost = 16000, requiredIds = {6785}},{id = 9750, cost = 16000, requiredIds = {8941}},},
	[44] = {{id = 22812, cost = 18000},{id = 9756, cost = 18000, requiredIds = {8914}},{id = 1824, cost = 18000, requiredIds = {1823}},{id = 9752, cost = 18000, requiredIds = {9493}},{id = 9754, cost = 18000, requiredIds = {769}},{id = 9758, cost = 18000, requiredIds = {8903}},},
	[46] = {{id = 9833, cost = 20000, requiredIds = {8929}},{id = 8905, cost = 20000, requiredIds = {6780}},{id = 8983, cost = 20000, requiredIds = {6798}},{id = 9821, cost = 20000, requiredIds = {1850}},{id = 22895, cost = 20000, requiredIds = {22842}},{id = 9823, cost = 20000, requiredIds = {9005}},{id = 9829, cost = 20000, requiredIds = {8992}},{id = 9839, cost = 20000, requiredIds = {8910}},},
	[48] = {{id = 9852, cost = 22000, requiredIds = {5196}},{id = 16813, cost = 1100, requiredIds = {16812,9852}, requiredTalentId = 16689},{id = 9849, cost = 22000, requiredIds = {5201}},{id = 22828, cost = 22000, requiredIds = {22827}},{id = 9845, cost = 22000, requiredIds = {6793}},{id = 9856, cost = 22000, requiredIds = {9750}},},
	[50] = {{id = 17401, cost = 23000, requiredIds = {16914}},{id = 24976, cost = 1150, requiredIds = {24975}, requiredTalentId = 5570},{id = 9875, cost = 23000, requiredIds = {8951}},{id = 9880, cost = 23000, requiredIds = {9745}},{id = 9866, cost = 23000, requiredIds = {6787}},{id = 21849, cost = 23000, requiredIds = {9884}},{id = 9888, cost = 23000, requiredIds = {9758}},{id = 9884, cost = 23000, requiredIds = {8907}},{id = 20747, cost = 23000, requiredIds = {20742}},{id = 9862, cost = 23000, requiredIds = {8918}},},
	[52] = {{id = 9834, cost = 26000, requiredIds = {9833}},{id = 9892, cost = 26000, requiredIds = {9000}},{id = 9898, cost = 26000, requiredIds = {9747}},{id = 9894, cost = 26000, requiredIds = {9752}},{id = 9840, cost = 26000, requiredIds = {9839}},},
	[54] = {{id = 9907, cost = 28000, requiredIds = {9749}},{id = 9901, cost = 28000, requiredIds = {8955}},{id = 9910, cost = 28000, requiredIds = {9756}},{id = 9912, cost = 28000, requiredIds = {8905}},{id = 17392, cost = 1400, requiredIds = {17391}, requiredTalentId = 16857},{id = 9904, cost = 28000, requiredIds = {1824}},{id = 9830, cost = 28000, requiredIds = {9829}},{id = 9908, cost = 28000, requiredIds = {9754}},{id = 9857, cost = 28000, requiredIds = {9856}},},
	[56] = {{id = 22829, cost = 30000, requiredIds = {22828}},{id = 22896, cost = 30000, requiredIds = {22895}},{id = 9827, cost = 30000, requiredIds = {9823}},{id = 9889, cost = 30000, requiredIds = {9888}},},
	[58] = {{id = 9853, cost = 32000, requiredIds = {9852}},{id = 18658, cost = 32000, requiredIds = {18657}},{id = 9835, cost = 32000, requiredIds = {9834}},{id = 17329, cost = 1600, requiredIds = {16813,9853}, requiredTalentId = 16689},{id = 9876, cost = 32000, requiredIds = {9875}},{id = 9850, cost = 32000, requiredIds = {9849}},{id = 33986, cost = 1700, requiredIds = {33878}, requiredTalentId = 33917},{id = 33982, cost = 1700, requiredIds = {33876}, requiredTalentId = 33917},{id = 9881, cost = 32000, requiredIds = {9880}},{id = 9867, cost = 32000, requiredIds = {9866}},{id = 9841, cost = 32000, requiredIds = {9840}},},
	[60] = {{id = 17402, cost = 34000, requiredIds = {17401}},{id = 24977, cost = 1700, requiredIds = {24976}, requiredTalentId = 5570},{id = 25298, cost = 34000, requiredIds = {9876}},{id = 31709, cost = 34000, requiredIds = {9892}},{id = 31018, cost = 30000, requiredIds = {22829}},{id = 9913, cost = 34000, requiredIds = {6783}},{id = 9896, cost = 34000, requiredIds = {9894}},{id = 9846, cost = 34000, requiredIds = {9845}},{id = 21850, cost = 34000, requiredIds = {21849}},{id = 25297, cost = 34000, requiredIds = {9889}},{id = 9885, cost = 34000, requiredIds = {9884}},{id = 20748, cost = 34000, requiredIds = {20747}},{id = 9858, cost = 34000, requiredIds = {9857}},{id = 25299, cost = 34000, requiredIds = {9841}},{id = 9863, cost = 34000, requiredIds = {9862}},},
	[61] = {{id = 26984, cost = 39000, requiredIds = {9912}},{id = 27001, cost = 39000, requiredIds = {9830}},},
	[62] = {{id = 26998, cost = 43000, requiredIds = {9898}},{id = 22570, cost = 43000},{id = 26978, cost = 43000, requiredIds = {25297}},},
	[63] = {{id = 26987, cost = 48000, requiredIds = {9835}},{id = 24248, cost = 48000, requiredIds = {31018}},{id = 26981, cost = 48000, requiredIds = {25299}},},
	[64] = {{id = 26992, cost = 53000, requiredIds = {9910}},{id = 27003, cost = 53000, requiredIds = {9904}},{id = 26997, cost = 53000, requiredIds = {9908}},{id = 33763, cost = 53000},},
	[65] = {{id = 33357, cost = 59000, requiredIds = {9821}},{id = 26999, cost = 59000, requiredIds = {22896}},{id = 26980, cost = 59000, requiredIds = {9858}},},
	[66] = {{id = 26993, cost = 34000, requiredIds = {9907}},{id = 27011, cost = 1700, requiredIds = {17392}, requiredTalentId = 16857},{id = 33745, cost = 66000},{id = 27006, cost = 66000, requiredIds = {9827}},{id = 27005, cost = 66000, requiredIds = {9867}},},
	[67] = {{id = 26986, cost = 73000, requiredIds = {25298}},{id = 27000, cost = 73000, requiredIds = {9850}},{id = 26996, cost = 73000, requiredIds = {9881}},{id = 27008, cost = 73000, requiredIds = {9896}},},
	[68] = {{id = 26989, cost = 81000, requiredIds = {9853}},{id = 27009, cost = 1700, requiredIds = {17329,26989}, requiredTalentId = 16689},{id = 33987, cost = 1900, requiredIds = {33986}, requiredTalentId = 33917},{id = 33983, cost = 1700, requiredIds = {33982}, requiredTalentId = 33917},{id = 33943, cost = 81000},},
	[69] = {{id = 26985, cost = 90000, requiredIds = {26984}},{id = 27004, cost = 90000, requiredIds = {31709}},{id = 26979, cost = 90000, requiredIds = {26978}},{id = 26994, cost = 90000, requiredIds = {20748}},{id = 26982, cost = 90000, requiredIds = {26981}},},
	[70] = {{id = 33786, cost = 100000},{id = 27012, cost = 100000, requiredIds = {17402}},{id = 27013, cost = 2500, requiredIds = {24977}, requiredTalentId = 5570},{id = 26988, cost = 100000, requiredIds = {26987}},{id = 26995, cost = 100000, requiredIds = {9901}},{id = 27002, cost = 100000, requiredIds = {27001}},{id = 26990, cost = 100000, requiredIds = {9885}},{id = 26983, cost = 100000, requiredIds = {9863}},},
}

-- HUNTER
Data.spellsByClass.HUNTER = {
	[1] = {{id = 1494, cost = 10},},
	[4] = {{id = 13163, cost = 100},{id = 1978, cost = 100},},
	[6] = {{id = 3044, cost = 100},{id = 1130, cost = 100},},
	[8] = {{id = 3127, cost = 200},{id = 5116, cost = 200},{id = 14260, cost = 200},},
	[10] = {{id = 13165, cost = 400},{id = 13549, cost = 400, requiredIds = {1978}},{id = 19883, cost = 400},{id = 4195, cost = 10},{id = 24547, cost = 10},},
	[12] = {{id = 136, cost = 600, requiredIds = {1515}},{id = 14281, cost = 600, requiredIds = {3044}},{id = 20736, cost = 600},{id = 2974, cost = 600},{id = 4196, cost = 120, requiredIds = {4195}},{id = 24556, cost = 120, requiredIds = {24547}},},
	[14] = {{id = 6197, cost = 1200},{id = 1002, cost = 1200},{id = 1513, cost = 1200},},
	[16] = {{id = 13795, cost = 1800},{id = 1495, cost = 1800},{id = 14261, cost = 1800, requiredIds = {14260}},},
	[18] = {{id = 14318, cost = 2000, requiredIds = {13165}},{id = 2643, cost = 2000},{id = 13550, cost = 2000, requiredIds = {13549}},{id = 19884, cost = 2000},{id = 4197, cost = 400, requiredIds = {4196}},{id = 24557, cost = 400, requiredIds = {24556}},},
	[20] = {{id = 5118, cost = 2200},{id = 3111, cost = 2200, requiredIds = {136}},{id = 674, cost = 2200},{id = 14282, cost = 2200, requiredIds = {14281}},{id = 14274, cost = 2200, requiredIds = {20736}},{id = 781, cost = 2200},{id = 1499, cost = 2200},{id = 24495, cost = 440},{id = 24440, cost = 440},{id = 24475, cost = 440},{id = 14923, cost = 440},{id = 24494, cost = 440},{id = 24490, cost = 440},},
	[22] = {{id = 14323, cost = 6000, requiredIds = {1130}},{id = 3043, cost = 6000},},
	[24] = {{id = 1462, cost = 7000},{id = 14262, cost = 7000, requiredIds = {14261}},{id = 19885, cost = 7000},{id = 4198, cost = 1400, requiredIds = {4197}},{id = 24558, cost = 1400, requiredIds = {24557}},},
	[26] = {{id = 3045, cost = 7000},{id = 13551, cost = 7000, requiredIds = {13550}},{id = 14302, cost = 7000, requiredIds = {13795}},{id = 19880, cost = 7000},},
	[28] = {{id = 14319, cost = 8000, requiredIds = {14318}},{id = 3661, cost = 8000, requiredIds = {3111}},{id = 20900, cost = 400, requiredIds = {19434}, requiredTalentId = 19434},{id = 14283, cost = 8000, requiredIds = {14282}},{id = 13809, cost = 8000},},
	[30] = {{id = 13161, cost = 8000},{id = 14326, cost = 8000, requiredIds = {1513}},{id = 15629, cost = 8000, requiredIds = {14274}},{id = 14288, cost = 8000, requiredIds = {2643}},{id = 5384, cost = 8000},{id = 14269, cost = 8000, requiredIds = {1495}},{id = 24508, cost = 1600, requiredIds = {24495}},{id = 35694, cost = 3000},{id = 25076, cost = 1600},{id = 24441, cost = 1600, requiredIds = {24440}},{id = 24476, cost = 1600, requiredIds = {24475}},{id = 4199, cost = 1600, requiredIds = {4198}},{id = 14924, cost = 1600, requiredIds = {14923}},{id = 24559, cost = 1600, requiredIds = {24558}},{id = 24511, cost = 1600, requiredIds = {24494}},{id = 24514, cost = 1600, requiredIds = {24490}},},
	[32] = {{id = 1543, cost = 10000},{id = 14263, cost = 10000, requiredIds = {14262}},{id = 19878, cost = 10000},},
	[34] = {{id = 13552, cost = 12000, requiredIds = {13551}},{id = 14272, cost = 12000, requiredIds = {781}},{id = 13813, cost = 12000},},
	[36] = {{id = 3662, cost = 14000, requiredIds = {3661}},{id = 20901, cost = 700, requiredIds = {20900}, requiredTalentId = 19434},{id = 14284, cost = 14000, requiredIds = {14283}},{id = 3034, cost = 14000},{id = 14303, cost = 14000, requiredIds = {14302}},{id = 4200, cost = 2800, requiredIds = {4199}},{id = 24560, cost = 2800, requiredIds = {24559}},},
	[38] = {{id = 14320, cost = 16000, requiredIds = {14319}},{id = 14267, cost = 16000, requiredIds = {2974}},},
	[40] = {{id = 13159, cost = 18000},{id = 8737, cost = 18000},{id = 15630, cost = 18000, requiredIds = {15629}},{id = 14324, cost = 18000, requiredIds = {14323}},{id = 1510, cost = 18000},{id = 14310, cost = 18000, requiredIds = {1499}},{id = 14264, cost = 18000, requiredIds = {14263}},{id = 19882, cost = 18000},{id = 24509, cost = 3600, requiredIds = {24508}},{id = 24463, cost = 3600, requiredIds = {24441}},{id = 24477, cost = 3600, requiredIds = {24476}},{id = 14925, cost = 3600, requiredIds = {14924}},{id = 24512, cost = 3600, requiredIds = {24511}},{id = 24515, cost = 3600, requiredIds = {24514}},},
	[42] = {{id = 14289, cost = 24000, requiredIds = {14288}},{id = 13553, cost = 24000, requiredIds = {13552}},{id = 20909, cost = 1200, requiredIds = {19306}, requiredTalentId = 19306},{id = 4201, cost = 4800, requiredIds = {4200}},{id = 24561, cost = 4800, requiredIds = {24560}},},
	[44] = {{id = 13542, cost = 26000, requiredIds = {3662}},{id = 20902, cost = 1300, requiredIds = {20901}, requiredTalentId = 19434},{id = 14285, cost = 26000, requiredIds = {14284}},{id = 14316, cost = 26000, requiredIds = {13813}},{id = 14270, cost = 26000, requiredIds = {14269}},},
	[46] = {{id = 20043, cost = 28000},{id = 14327, cost = 28000, requiredIds = {14326}},{id = 14279, cost = 28000, requiredIds = {3034}},{id = 14304, cost = 28000, requiredIds = {14303}},},
	[48] = {{id = 14321, cost = 32000, requiredIds = {14320}},{id = 14273, cost = 32000, requiredIds = {14272}},{id = 14265, cost = 32000, requiredIds = {14264}},{id = 4202, cost = 6400, requiredIds = {4201}},{id = 24562, cost = 6400, requiredIds = {24561}},},
	[50] = {{id = 15631, cost = 36000, requiredIds = {15630}},{id = 13554, cost = 36000, requiredIds = {13553}},{id = 20905, cost = 1800, requiredIds = {19506}, requiredTalentId = 19506},{id = 14294, cost = 36000, requiredIds = {1510}},{id = 19879, cost = 36000},{id = 24132, cost = 1800, requiredIds = {19386}, requiredTalentId = 19386},{id = 24510, cost = 7200, requiredIds = {24509}},{id = 24464, cost = 7200, requiredIds = {24463}},{id = 24478, cost = 7200, requiredIds = {24477}},{id = 14926, cost = 7200, requiredIds = {14925}},{id = 24513, cost = 7200, requiredIds = {24512}},{id = 24516, cost = 7200, requiredIds = {24515}},},
	[52] = {{id = 13543, cost = 40000, requiredIds = {13542}},{id = 20903, cost = 2000, requiredIds = {20902}, requiredTalentId = 19434},{id = 14286, cost = 40000, requiredIds = {14285}},},
	[54] = {{id = 14290, cost = 42000, requiredIds = {14289}},{id = 20910, cost = 2100, requiredIds = {20909}, requiredTalentId = 19306},{id = 14317, cost = 42000, requiredIds = {14316}},{id = 5048, cost = 8400, requiredIds = {4202}},{id = 24631, cost = 8400, requiredIds = {24562}},},
	[56] = {{id = 20190, cost = 46000, requiredIds = {20043}},{id = 14280, cost = 46000, requiredIds = {14279}},{id = 14305, cost = 46000, requiredIds = {14304}},{id = 14266, cost = 46000, requiredIds = {14265}},},
	[58] = {{id = 14322, cost = 48000, requiredIds = {14321}},{id = 14325, cost = 48000, requiredIds = {14324}},{id = 13555, cost = 48000, requiredIds = {13554}},{id = 14295, cost = 48000, requiredIds = {14294}},{id = 14271, cost = 48000, requiredIds = {14270}},},
	[60] = {{id = 25296, cost = 50000, requiredIds = {14322}},{id = 13544, cost = 50000, requiredIds = {13543}},{id = 20904, cost = 2500, requiredIds = {20903}, requiredTalentId = 19434},{id = 14287, cost = 50000, requiredIds = {14286}},{id = 15632, cost = 50000, requiredIds = {15631}},{id = 25294, cost = 50000, requiredIds = {14290}},{id = 25295, cost = 50000, requiredIds = {13555}},{id = 19801, cost = 50000},{id = 20906, cost = 2500, requiredIds = {20905}, requiredTalentId = 19506},{id = 14311, cost = 50000, requiredIds = {14310}},{id = 14268, cost = 50000, requiredIds = {14267}},{id = 24133, cost = 2500, requiredIds = {24132}, requiredTalentId = 19386},{id = 27052, cost = 10000, requiredIds = {24510}},{id = 35698, cost = 10000},{id = 27053, cost = 10000, requiredIds = {24464}},{id = 27054, cost = 10000, requiredIds = {24478}},{id = 5049, cost = 10000, requiredIds = {5048}},{id = 14927, cost = 10000, requiredIds = {14926}},{id = 24632, cost = 10000, requiredIds = {24631}},{id = 27055, cost = 10000, requiredIds = {24513}},{id = 27056, cost = 10000, requiredIds = {24516}},},
	[61] = {{id = 27025, cost = 68000, requiredIds = {14317}},},
	[62] = {{id = 34120, cost = 77000},{id = 27015, cost = 77000, requiredIds = {14273}},},
	[63] = {{id = 27014, cost = 87000, requiredIds = {14266}},},
	[64] = {{id = 34074, cost = 100000},},
	[65] = {{id = 27023, cost = 110000, requiredIds = {14305}},},
	[66] = {{id = 34026, cost = 120000},{id = 27018, cost = 120000, requiredIds = {14280}},{id = 27067, cost = 2500, requiredIds = {20910}, requiredTalentId = 19306},},
	[67] = {{id = 27021, cost = 140000, requiredIds = {25294}},{id = 27016, cost = 140000, requiredIds = {25295}},{id = 27022, cost = 140000, requiredIds = {14295}},},
	[68] = {{id = 27044, cost = 150000, requiredIds = {25296}},{id = 27045, cost = 150000, requiredIds = {20190}},{id = 27046, cost = 150000, requiredIds = {13544}},{id = 34600, cost = 150000},},
	[69] = {{id = 27019, cost = 170000, requiredIds = {14287}},{id = 27020, cost = 170000, requiredIds = {15632}},},
	[70] = {{id = 27065, cost = 2700, requiredIds = {20904}, requiredTalentId = 19434},{id = 27066, cost = 2700, requiredIds = {20906}, requiredTalentId = 19506},{id = 34477, cost = 190000},{id = 36916, cost = 190000, requiredIds = {14271}},{id = 27068, cost = 2700, requiredIds = {24133}, requiredTalentId = 19386},{id = 27062, cost = 10000, requiredIds = {5049}},{id = 27047, cost = 12000, requiredIds = {14927}},{id = 27061, cost = 10000, requiredIds = {24632}},},
}

-- MAGE
Data.spellsByClass.MAGE = {
	[1] = {{id = 1459, cost = 10},},
	[4] = {{id = 5504, cost = 100},{id = 116, cost = 100},},
	[6] = {{id = 587, cost = 100},{id = 2136, cost = 100},{id = 143, cost = 100, requiredIds = {133}},},
	[8] = {{id = 5143, cost = 200},{id = 118, cost = 200},{id = 205, cost = 200, requiredIds = {116}},},
	[10] = {{id = 5505, cost = 400, requiredIds = {5504}},{id = 7300, cost = 400, requiredIds = {168}},{id = 122, cost = 400},},
	[12] = {{id = 597, cost = 600, requiredIds = {587}},{id = 604, cost = 600},{id = 130, cost = 600},{id = 145, cost = 600, requiredIds = {143}},},
	[14] = {{id = 1449, cost = 900},{id = 1460, cost = 900, requiredIds = {1459}},{id = 2137, cost = 900, requiredIds = {2136}},{id = 837, cost = 900, requiredIds = {205}},},
	[16] = {{id = 5144, cost = 1500, requiredIds = {5143}},{id = 2120, cost = 1500},},
	[18] = {{id = 1008, cost = 1800},{id = 475, cost = 1800},{id = 3140, cost = 1800, requiredIds = {145}},},
	[20] = {{id = 1953, cost = 2000},{id = 5506, cost = 2000, requiredIds = {5505}},{id = 12051, cost = 2000},{id = 1463, cost = 2000},{id = 12824, cost = 2000, requiredIds = {118}},{id = 543, cost = 2000},{id = 10, cost = 2000},{id = 7301, cost = 2000, requiredIds = {7300}},{id = 7322, cost = 2000, requiredIds = {837}},{id = 3561, cost = 2000, faction = "Alliance"},{id = 3562, cost = 2000, faction = "Alliance"},{id = 32271, cost = 2000, faction = "Alliance"},{id = 3567, cost = 2000, faction = "Horde"},{id = 3563, cost = 2000, faction = "Horde"},{id = 32272, cost = 2000, faction = "Horde"},},
	[22] = {{id = 8437, cost = 3000, requiredIds = {1449}},{id = 990, cost = 3000, requiredIds = {597}},{id = 2138, cost = 3000, requiredIds = {2137}},{id = 2948, cost = 3000},{id = 6143, cost = 3000},},
	[24] = {{id = 5145, cost = 4000, requiredIds = {5144}},{id = 2139, cost = 4000},{id = 8450, cost = 4000, requiredIds = {604}},{id = 8400, cost = 4000, requiredIds = {3140}},{id = 2121, cost = 4000, requiredIds = {2120}},{id = 12505, cost = 1000, requiredIds = {11366}, requiredTalentId = 11366},},
	[26] = {{id = 120, cost = 5000},{id = 865, cost = 5000, requiredIds = {122}},{id = 8406, cost = 5000, requiredIds = {7322}},},
	[28] = {{id = 1461, cost = 7000, requiredIds = {1460}},{id = 759, cost = 7000},{id = 8494, cost = 7000, requiredIds = {1463}},{id = 8444, cost = 7000, requiredIds = {2948}},{id = 6141, cost = 7000, requiredIds = {10}},},
	[30] = {{id = 8455, cost = 8000, requiredIds = {1008}},{id = 8438, cost = 8000, requiredIds = {8437}},{id = 6127, cost = 8000, requiredIds = {5506}},{id = 8412, cost = 8000, requiredIds = {2138}},{id = 8457, cost = 8000, requiredIds = {543}},{id = 8401, cost = 8000, requiredIds = {8400}},{id = 12522, cost = 2000, requiredIds = {12505}, requiredTalentId = 11366},{id = 7302, cost = 8000},{id = 45438, cost = 8000},{id = 3565, cost = 8000, faction = "Alliance"},{id = 3566, cost = 8000, faction = "Horde"},},
	[32] = {{id = 8416, cost = 10000, requiredIds = {5145}},{id = 6129, cost = 10000, requiredIds = {990}},{id = 8422, cost = 10000, requiredIds = {2121}},{id = 8461, cost = 10000, requiredIds = {6143}},{id = 8407, cost = 10000, requiredIds = {8406}},},
	[34] = {{id = 6117, cost = 13000},{id = 8445, cost = 12000, requiredIds = {8444}},{id = 8492, cost = 12000, requiredIds = {120}},},
	[35] = {{id = 49360, cost = 15000, faction = "Alliance"},{id = 49359, cost = 2000, faction = "Alliance"},{id = 49361, cost = 15000, faction = "Horde"},{id = 49358, cost = 2000, faction = "Horde"},},
	[36] = {{id = 8451, cost = 13000, requiredIds = {8450}},{id = 8495, cost = 13000, requiredIds = {8494}},{id = 13018, cost = 3250, requiredIds = {11113}, requiredTalentId = 11113},{id = 8402, cost = 13000, requiredIds = {8401}},{id = 12523, cost = 3250, requiredIds = {12522}, requiredTalentId = 11366},{id = 8427, cost = 13000, requiredIds = {6141}},},
	[38] = {{id = 8439, cost = 14000, requiredIds = {8438}},{id = 3552, cost = 14000, requiredIds = {759}},{id = 8413, cost = 14000, requiredIds = {8412}},{id = 8408, cost = 14000, requiredIds = {8407}},},
	[40] = {{id = 8417, cost = 15000, requiredIds = {8416}},{id = 10138, cost = 15000, requiredIds = {6127}},{id = 12825, cost = 15000, requiredIds = {12824}},{id = 8458, cost = 15000, requiredIds = {8457}},{id = 8423, cost = 15000, requiredIds = {8422}},{id = 8446, cost = 15000, requiredIds = {8445}},{id = 6131, cost = 15000, requiredIds = {865}},{id = 7320, cost = 15000, requiredIds = {7302}},{id = 10059, cost = 15000, faction = "Alliance"},{id = 11416, cost = 15000, faction = "Alliance"},{id = 32266, cost = 15000, faction = "Alliance"},{id = 11417, cost = 15000, faction = "Horde"},{id = 11418, cost = 15000, faction = "Horde"},{id = 32267, cost = 15000, faction = "Horde"},},
	[42] = {{id = 10169, cost = 18000, requiredIds = {8455}},{id = 10156, cost = 18000, requiredIds = {1461}},{id = 10144, cost = 18000, requiredIds = {6129}},{id = 10148, cost = 18000, requiredIds = {8402}},{id = 12524, cost = 4500, requiredIds = {12523}, requiredTalentId = 11366},{id = 10159, cost = 18000, requiredIds = {8492}},{id = 8462, cost = 18000, requiredIds = {8461}},},
	[44] = {{id = 10191, cost = 23000, requiredIds = {8495}},{id = 13019, cost = 5749, requiredIds = {13018}, requiredTalentId = 11113},{id = 10185, cost = 23000, requiredIds = {8427}},{id = 10179, cost = 23000, requiredIds = {8408}},},
	[46] = {{id = 10201, cost = 26000, requiredIds = {8439}},{id = 22782, cost = 28000, requiredIds = {6117}},{id = 10197, cost = 26000, requiredIds = {8413}},{id = 10205, cost = 26000, requiredIds = {8446}},{id = 13031, cost = 1700, requiredIds = {11426}, requiredTalentId = 11426},},
	[48] = {{id = 10211, cost = 28000, requiredIds = {8417}},{id = 10053, cost = 28000, requiredIds = {3552}},{id = 10173, cost = 28000, requiredIds = {8451}},{id = 10149, cost = 28000, requiredIds = {10148}},{id = 10215, cost = 28000, requiredIds = {8423}},{id = 12525, cost = 7000, requiredIds = {12524}, requiredTalentId = 11366},},
	[50] = {{id = 10139, cost = 32000, requiredIds = {10138}},{id = 10223, cost = 32000, requiredIds = {8458}},{id = 10160, cost = 32000, requiredIds = {10159}},{id = 10180, cost = 32000, requiredIds = {10179}},{id = 10219, cost = 32000, requiredIds = {7320}},{id = 11419, cost = 32000, faction = "Alliance"},{id = 11420, cost = 32000, faction = "Horde"},},
	[52] = {{id = 10145, cost = 35000, requiredIds = {10144}},{id = 10192, cost = 35000, requiredIds = {10191}},{id = 13020, cost = 8749, requiredIds = {13019}, requiredTalentId = 11113},{id = 10206, cost = 35000, requiredIds = {10205}},{id = 10186, cost = 35000, requiredIds = {10185}},{id = 10177, cost = 35000, requiredIds = {8462}},{id = 13032, cost = 1900, requiredIds = {13031}, requiredTalentId = 11426},},
	[54] = {{id = 10170, cost = 36000, requiredIds = {10169}},{id = 10202, cost = 36000, requiredIds = {10201}},{id = 10199, cost = 36000, requiredIds = {10197}},{id = 10150, cost = 36000, requiredIds = {10149}},{id = 12526, cost = 9000, requiredIds = {12525}, requiredTalentId = 11366},{id = 10230, cost = 36000, requiredIds = {6131}},},
	[56] = {{id = 23028, cost = 38000, requiredIds = {10157}},{id = 10157, cost = 38000, requiredIds = {10156}},{id = 10212, cost = 38000, requiredIds = {10211}},{id = 33041, cost = 1900, requiredIds = {31661}, requiredTalentId = 31661},{id = 10216, cost = 38000, requiredIds = {10215}},{id = 10181, cost = 38000, requiredIds = {10180}},},
	[58] = {{id = 10054, cost = 40000, requiredIds = {10053}},{id = 22783, cost = 40000, requiredIds = {22782}},{id = 10207, cost = 40000, requiredIds = {10206}},{id = 10161, cost = 40000, requiredIds = {10160}},{id = 13033, cost = 2100, requiredIds = {13032}, requiredTalentId = 11426},},
	[60] = {{id = 25345, cost = 42000, requiredIds = {10212}},{id = 28612, cost = 42000, requiredIds = {10145}},{id = 10140, cost = 42000, requiredIds = {10139}},{id = 10174, cost = 42000, requiredIds = {10173}},{id = 10193, cost = 42000, requiredIds = {10192}},{id = 12826, cost = 42000, requiredIds = {12825}},{id = 13021, cost = 10500, requiredIds = {13020}, requiredTalentId = 11113},{id = 10225, cost = 42000, requiredIds = {10223}},{id = 10151, cost = 42000, requiredIds = {10150}},{id = 18809, cost = 10500, requiredIds = {12526}, requiredTalentId = 11366},{id = 10187, cost = 42000, requiredIds = {10186}},{id = 28609, cost = 42000, requiredIds = {10177}},{id = 25304, cost = 42000, requiredIds = {10181}},{id = 10220, cost = 42000, requiredIds = {10219}},{id = 33690, cost = 20000, faction = "Alliance"},{id = 35715, cost = 20000, faction = "Horde"},},
	[61] = {{id = 27078, cost = 46000, requiredIds = {10199}},},
	[62] = {{id = 27080, cost = 51000, requiredIds = {10202}},{id = 25306, cost = 42000, requiredIds = {10151}},{id = 30482, cost = 51000},},
	[63] = {{id = 27130, cost = 57000, requiredIds = {10170}},{id = 27075, cost = 57000, requiredIds = {25345}},{id = 27071, cost = 57000, requiredIds = {25304}},},
	[64] = {{id = 30451, cost = 63000},{id = 33042, cost = 2200, requiredIds = {33041}, requiredTalentId = 31661},{id = 27086, cost = 63000, requiredIds = {10216}},{id = 27134, cost = 2500, requiredIds = {13033}, requiredTalentId = 11426},},
	[65] = {{id = 37420, cost = 70000, requiredIds = {10140}},{id = 27133, cost = 10500, requiredIds = {13021}, requiredTalentId = 11113},{id = 27073, cost = 70000, requiredIds = {10207}},{id = 27087, cost = 70000, requiredIds = {10161}},{id = 35717, cost = 150000, faction = "Horde"},{id = 33691, cost = 150000, faction = "Alliance"},},
	[66] = {{id = 27070, cost = 78000, requiredIds = {25306}},{id = 27132, cost = 10500, requiredIds = {18809}, requiredTalentId = 11366},{id = 30455, cost = 78000},},
	[67] = {{id = 33944, cost = 87000, requiredIds = {10174}},{id = 27088, cost = 87000, requiredIds = {10230}},},
	[68] = {{id = 27101, cost = 96000, requiredIds = {10054}},{id = 66, cost = 96000},{id = 27131, cost = 96000, requiredIds = {10193}},{id = 27085, cost = 96000, requiredIds = {10187}},},
	[69] = {{id = 33946, cost = 110000, requiredIds = {27130}},{id = 38699, cost = 87000, requiredIds = {27075}},{id = 27125, cost = 110000, requiredIds = {22783}},{id = 27128, cost = 110000, requiredIds = {10225}},{id = 27072, cost = 110000, requiredIds = {27071}},{id = 27124, cost = 110000, requiredIds = {10220}},},
	[70] = {{id = 27082, cost = 120000, requiredIds = {27080}},{id = 27126, cost = 120000, requiredIds = {10157}},{id = 43987, cost = 120000, requiredIds = {27090,33717}},{id = 30449, cost = 120000},{id = 33933, cost = 12500, requiredIds = {27133}, requiredTalentId = 11113},{id = 33043, cost = 2500, requiredIds = {33042}, requiredTalentId = 31661},{id = 27079, cost = 120000, requiredIds = {27078}},{id = 33938, cost = 10500, requiredIds = {27132}, requiredTalentId = 11366},{id = 27074, cost = 120000, requiredIds = {27073}},{id = 32796, cost = 120000, requiredIds = {28609}},{id = 33405, cost = 10500, requiredIds = {27134}, requiredTalentId = 11426},},
}

-- PALADIN
-- Paladin Auras are special in that you never have multiple ranks in the spellbook, only the latest one is usable
-- Even so, IsSpellKnown will only return true for your current rank

-- These tables are ordered by rank
local devotionAura = {465,10290,643,10291,1032,10292,10293,27149}
local layonHands = {633,2800,10310,27154}
local retributionAura = {7294,10298,10299,10300,10301,27150}
local shadowResistanceAura = {19876,19895,19896,27151}
local frostResistanceAura = {19888,19897,19898,27152}
local fireResistanceAura = {19891,19899,19900,27153}
local spiritualAttunement = {31785,33776}
Data.overriddenByClass.PALADIN = {devotionAura,layonHands,retributionAura,shadowResistanceAura,frostResistanceAura,fireResistanceAura,spiritualAttunement}
Data.spellsByClass.PALADIN = {
	[1] = {{id = 465, cost = 10},},
	[4] = {{id = 19740, cost = 100},{id = 20271, cost = 100},},
	[6] = {{id = 639, cost = 100, requiredIds = {635}},{id = 498, cost = 100},{id = 21082, cost = 100},},
	[8] = {{id = 3127, cost = 100},{id = 1152, cost = 100},{id = 853, cost = 100},},
	[10] = {{id = 633, cost = 300},{id = 20287, cost = 300, requiredIds = {21084}},{id = 1022, cost = 300},{id = 10290, cost = 300, requiredIds = {465}},},
	[12] = {{id = 19834, cost = 1000, requiredIds = {19740}},{id = 20162, cost = 1000, requiredIds = {21082}},},
	[14] = {{id = 19742, cost = 2000},{id = 647, cost = 2000, requiredIds = {639}},{id = 31789, cost = 4000},},
	[16] = {{id = 25780, cost = 3000},{id = 7294, cost = 3000},},
	[18] = {{id = 20288, cost = 3500, requiredIds = {20287}},{id = 1044, cost = 3500},{id = 5573, cost = 3500, requiredIds = {498}},{id = 31785, cost = 3500},},
	[20] = {{id = 26573, cost = 4000},{id = 879, cost = 4000},{id = 19750, cost = 4000},{id = 643, cost = 4000, requiredIds = {10290}},},
	[22] = {{id = 1026, cost = 4000, requiredIds = {647}},{id = 19746, cost = 4000},{id = 20164, cost = 4000},{id = 19835, cost = 4000, requiredIds = {19834}},{id = 20305, cost = 4000, requiredIds = {20162}},},
	[24] = {{id = 19850, cost = 5000, requiredIds = {19742}},{id = 10322, cost = 5000, requiredIds = {7328}},{id = 2878, cost = 5000},{id = 5599, cost = 5000, requiredIds = {1022}},{id = 5588, cost = 5000, requiredIds = {853}},},
	[26] = {{id = 19939, cost = 6000, requiredIds = {19750}},{id = 20289, cost = 6000, requiredIds = {20288}},{id = 1038, cost = 6000},{id = 10298, cost = 6000, requiredIds = {7294}},},
	[28] = {{id = 5614, cost = 9000, requiredIds = {879}},{id = 19876, cost = 9000},},
	[30] = {{id = 20116, cost = 11000, requiredIds = {26573}},{id = 1042, cost = 11000, requiredIds = {1026}},{id = 2800, cost = 11000, requiredIds = {633}},{id = 20165, cost = 11000},{id = 34769, cost = 10000, faction = "Horde"},{id = 10291, cost = 11000, requiredIds = {643}},{id = 19752, cost = 11000},{id = 20915, cost = 550, requiredIds = {20375}, requiredTalentId = 20375},},
	[32] = {{id = 19888, cost = 12000},{id = 19836, cost = 12000, requiredIds = {19835}},{id = 20306, cost = 12000, requiredIds = {20305}},},
	[34] = {{id = 19852, cost = 13000, requiredIds = {19850}},{id = 19940, cost = 13000, requiredIds = {19939}},{id = 20290, cost = 13000, requiredIds = {20289}},{id = 642, cost = 13000},},
	[36] = {{id = 5615, cost = 14000, requiredIds = {5614}},{id = 10324, cost = 14000, requiredIds = {10322}},{id = 19891, cost = 14000},{id = 10299, cost = 14000, requiredIds = {10298}},},
	[38] = {{id = 3472, cost = 16000, requiredIds = {1042}},{id = 20166, cost = 16000},{id = 5627, cost = 16000, requiredIds = {2878}},{id = 10278, cost = 16000, requiredIds = {5599}},},
	[40] = {{id = 19977, cost = 20000},{id = 20922, cost = 20000, requiredIds = {20116}},{id = 20347, cost = 20000, requiredIds = {20165}},{id = 750, cost = 20000},{id = 20912, cost = 1000, requiredIds = {20911}, requiredTalentId = 20911},{id = 1032, cost = 20000, requiredIds = {10291}},{id = 5589, cost = 20000, requiredIds = {5588}},{id = 19895, cost = 20000, requiredIds = {19876}},{id = 20918, cost = 1000, requiredIds = {20915}, requiredTalentId = 20375},},
	[42] = {{id = 4987, cost = 21000},{id = 19941, cost = 21000, requiredIds = {19940}},{id = 20291, cost = 21000, requiredIds = {20290}},{id = 19837, cost = 21000, requiredIds = {19836}},{id = 20307, cost = 21000, requiredIds = {20306}},},
	[44] = {{id = 19853, cost = 22000, requiredIds = {19852}},{id = 10312, cost = 22000, requiredIds = {5615}},{id = 24275, cost = 22000},{id = 19897, cost = 22000, requiredIds = {19888}},},
	[46] = {{id = 10328, cost = 24000, requiredIds = {3472}},{id = 6940, cost = 24000},{id = 10300, cost = 24000, requiredIds = {10299}},},
	[48] = {{id = 20929, cost = 1300, requiredIds = {20473}, requiredTalentId = 20473},{id = 20772, cost = 26000, requiredIds = {10324}},{id = 20356, cost = 26000, requiredIds = {20166}},{id = 19899, cost = 26000, requiredIds = {19891}},{id = 31895, cost = 26000, requiredIds = {20164}},},
	[50] = {{id = 19978, cost = 28000, requiredIds = {19977}},{id = 20923, cost = 28000, requiredIds = {20922}},{id = 19942, cost = 28000, requiredIds = {19941}},{id = 2812, cost = 28000},{id = 10310, cost = 28000, requiredIds = {2800}},{id = 20348, cost = 28000, requiredIds = {20347}},{id = 20292, cost = 28000, requiredIds = {20291}},{id = 20913, cost = 1400, requiredIds = {20912}, requiredTalentId = 20911},{id = 10292, cost = 28000, requiredIds = {1032}},{id = 1020, cost = 28000, requiredIds = {642}},{id = 20927, cost = 1400, requiredIds = {20925}, requiredTalentId = 20925},{id = 20919, cost = 1400, requiredIds = {20918}, requiredTalentId = 20375},},
	[52] = {{id = 10313, cost = 34000, requiredIds = {10312}},{id = 24274, cost = 34000, requiredIds = {24275}},{id = 10326, cost = 34000, requiredIds = {5627}},{id = 19896, cost = 34000, requiredIds = {19895}},{id = 19838, cost = 34000, requiredIds = {19837}},{id = 25782, cost = 46000, requiredIds = {19838}},{id = 20308, cost = 34000, requiredIds = {20307}},},
	[54] = {{id = 19854, cost = 40000, requiredIds = {19853}},{id = 25894, cost = 46000, requiredIds = {19854}},{id = 10329, cost = 40000, requiredIds = {10328}},{id = 20729, cost = 40000, requiredIds = {6940}},{id = 10308, cost = 40000, requiredIds = {5589}},},
	[56] = {{id = 20930, cost = 2100, requiredIds = {20929}, requiredTalentId = 20473},{id = 19898, cost = 42000, requiredIds = {19897}},{id = 10301, cost = 42000, requiredIds = {10300}},},
	[58] = {{id = 19943, cost = 44000, requiredIds = {19942}},{id = 20293, cost = 44000, requiredIds = {20292}},{id = 20357, cost = 44000, requiredIds = {20356}},},
	[60] = {{id = 19979, cost = 46000, requiredIds = {19978}},{id = 25290, cost = 50000, requiredIds = {19854}},{id = 20924, cost = 46000, requiredIds = {20923}},{id = 10314, cost = 46000, requiredIds = {10313}},{id = 25890, cost = 46000, requiredIds = {19979}},{id = 25918, cost = 46000, requiredIds = {25290,25894}},{id = 24239, cost = 46000, requiredIds = {24274}},{id = 25292, cost = 46000, requiredIds = {10329}},{id = 10318, cost = 46000, requiredIds = {2812}},{id = 20773, cost = 46000, requiredIds = {20772}},{id = 20349, cost = 46000, requiredIds = {20348}},{id = 32699, cost = 2300, requiredIds = {31935}, requiredTalentId = 31935},{id = 20914, cost = 2300, requiredIds = {20913}, requiredTalentId = 20911},{id = 10293, cost = 46000, requiredIds = {10292}},{id = 19900, cost = 46000, requiredIds = {19899}},{id = 25898, cost = 2300, requiredIds = {20217}, requiredTalentId = 20217},{id = 25895, cost = 46000, requiredIds = {1038}},{id = 25899, cost = 2300, requiredIds = {20914}, requiredTalentId = 20911},{id = 20928, cost = 2300, requiredIds = {20927}, requiredTalentId = 20925},{id = 25291, cost = 50000, requiredIds = {19838}},{id = 25916, cost = 46000, requiredIds = {25291,25782}},{id = 20920, cost = 2300, requiredIds = {20919}, requiredTalentId = 20375},},
	[61] = {{id = 27158, cost = 50000, requiredIds = {20308}},},
	[62] = {{id = 27135, cost = 55000, requiredIds = {25292}},{id = 27147, cost = 55000, requiredIds = {20729}},{id = 32223, cost = 55000},},
	[63] = {{id = 27151, cost = 61000, requiredIds = {19896}},},
	[64] = {{id = 27174, cost = 3350, requiredIds = {20930}, requiredTalentId = 20473},{id = 31801, cost = 67000, faction = "Alliance"},{id = 31892, cost = 67000, faction = "Horde"},},
	[65] = {{id = 27142, cost = 75000, requiredIds = {25290}},{id = 27143, cost = 75000, requiredIds = {27142,25918}},},
	[66] = {{id = 27137, cost = 83000, requiredIds = {19943}},{id = 27155, cost = 83000, requiredIds = {20293}},{id = 33776, cost = 83000, requiredIds = {31785}},{id = 27150, cost = 83000, requiredIds = {10301}},},
	[67] = {{id = 27166, cost = 92000, requiredIds = {20357}},},
	[68] = {{id = 27138, cost = 100000, requiredIds = {10314}},{id = 27180, cost = 100000, requiredIds = {24239}},{id = 27152, cost = 100000, requiredIds = {19898}},},
	[69] = {{id = 27144, cost = 110000, requiredIds = {19979}},{id = 27145, cost = 110000, requiredIds = {27144,25890}},{id = 27139, cost = 110000, requiredIds = {10318}},{id = 27154, cost = 110000, requiredIds = {10310}},{id = 27160, cost = 110000, requiredIds = {20349}},},
	[70] = {{id = 27173, cost = 130000, requiredIds = {20924}},{id = 27136, cost = 130000, requiredIds = {27135}},{id = 33072, cost = 6500, requiredIds = {27174}, requiredTalentId = 20473},{id = 32700, cost = 2300, requiredIds = {32699}, requiredTalentId = 31935},{id = 27148, cost = 130000, requiredIds = {27147}},{id = 27168, cost = 2300, requiredIds = {20914}, requiredTalentId = 20911},{id = 27149, cost = 130000, requiredIds = {10293}},{id = 27153, cost = 130000, requiredIds = {19900}},{id = 27169, cost = 2300, requiredIds = {27168,25899}, requiredTalentId = 20911},{id = 27179, cost = 2300, requiredIds = {20928}, requiredTalentId = 20925},{id = 31884, cost = 130000},{id = 27140, cost = 50000, requiredIds = {25291}},{id = 27141, cost = 46000, requiredIds = {27140,25916}},{id = 27170, cost = 2300, requiredIds = {20920}, requiredTalentId = 20375},{id = 348700, cost = 67000, faction = "Alliance"},{id = 348704, cost = 67000, faction = "Horde"},},
}

-- PRIEST
Data.spellsByClass.PRIEST = {
	[1] = {{id = 1243, cost = 10},},
	[4] = {{id = 2052, cost = 100, requiredIds = {2050}},{id = 589, cost = 100},},
	[6] = {{id = 17, cost = 100},{id = 591, cost = 100, requiredIds = {585}},},
	[8] = {{id = 139, cost = 200},{id = 586, cost = 200},},
	[10] = {{id = 2053, cost = 300, requiredIds = {2052}},{id = 2006, cost = 300},{id = 8092, cost = 300},{id = 594, cost = 300, requiredIds = {589}},{id = 2652, cost = 90, races = {5, 10}},{id = 32548, cost = 100, race = 11},{id = 10797, cost = 90, race = 4},{id = 9035, cost = 90, race = 8},{id = 13908, cost = 90, races = {1, 3}},},
	[12] = {{id = 588, cost = 800},{id = 1244, cost = 800, requiredIds = {1243}},{id = 592, cost = 800, requiredIds = {17}},},
	[14] = {{id = 528, cost = 1200},{id = 6074, cost = 1200, requiredIds = {139}},{id = 598, cost = 1200, requiredIds = {591}},{id = 8122, cost = 1200},},
	[16] = {{id = 2054, cost = 1600},{id = 8102, cost = 1600, requiredIds = {8092}},},
	[18] = {{id = 527, cost = 2000},{id = 600, cost = 2000, requiredIds = {592}},{id = 970, cost = 2000, requiredIds = {594}},{id = 19296, cost = 100, requiredIds = {10797}, race = 4},{id = 19236, cost = 100, requiredIds = {13908}, races = {1, 3}},},
	[20] = {{id = 6346, cost = 800},{id = 7128, cost = 3000, requiredIds = {588}},{id = 9484, cost = 3000},{id = 2061, cost = 3000},{id = 14914, cost = 3000},{id = 6075, cost = 3000, requiredIds = {6074}},{id = 2944, cost = 100, race = 5},{id = 9578, cost = 3000, requiredIds = {586}},{id = 453, cost = 3000},{id = 19261, cost = 150, requiredIds = {2652}, races = {5, 10}},{id = 44041, cost = 100, races = {3, 11}},{id = 2651, cost = 100, race = 4},{id = 19281, cost = 150, requiredIds = {9035}, race = 8},{id = 18137, cost = 100, race = 8},{id = 13896, cost = 100, race = 1},{id = 32676, cost = 100, race = 10},},
	[22] = {{id = 2055, cost = 4000, requiredIds = {2054}},{id = 2010, cost = 4000, requiredIds = {2006}},{id = 984, cost = 4000, requiredIds = {598}},{id = 8103, cost = 4000, requiredIds = {8102}},{id = 2096, cost = 4000},},
	[24] = {{id = 8129, cost = 5000},{id = 1245, cost = 5000, requiredIds = {1244}},{id = 3747, cost = 5000, requiredIds = {600}},{id = 15262, cost = 5000, requiredIds = {14914}},},
	[26] = {{id = 9472, cost = 6000, requiredIds = {2061}},{id = 6076, cost = 6000, requiredIds = {6075}},{id = 992, cost = 6000, requiredIds = {970}},{id = 19299, cost = 300, requiredIds = {19296}, race = 4},{id = 19238, cost = 300, requiredIds = {19236}, races = {1, 3}},},
	[28] = {{id = 6063, cost = 8000, requiredIds = {2055}},{id = 15430, cost = 400, requiredIds = {15237}, requiredTalentId = 15237},{id = 19276, cost = 400, requiredIds = {2944}, race = 5},{id = 8104, cost = 8000, requiredIds = {8103}},{id = 17311, cost = 400, requiredIds = {15407}, requiredTalentId = 15407},{id = 8124, cost = 8000, requiredIds = {8122}},{id = 19308, cost = 400, requiredIds = {18137}, race = 8},},
	[30] = {{id = 602, cost = 10000, requiredIds = {7128}},{id = 6065, cost = 10000, requiredIds = {3747}},{id = 15263, cost = 10000, requiredIds = {15262}},{id = 596, cost = 10000},{id = 1004, cost = 10000, requiredIds = {984}},{id = 9579, cost = 10000, requiredIds = {9578}},{id = 605, cost = 10000},{id = 976, cost = 10000},{id = 19262, cost = 500, requiredIds = {19261}, races = {5, 10}},{id = 44043, cost = 500, requiredIds = {44041}, races = {3, 11}},{id = 19282, cost = 500, requiredIds = {19281}, race = 8},{id = 19271, cost = 500, requiredIds = {13896}, race = 1},},
	[32] = {{id = 8131, cost = 11000, requiredIds = {8129}},{id = 552, cost = 11000},{id = 9473, cost = 11000, requiredIds = {9472}},{id = 6077, cost = 11000, requiredIds = {6076}},},
	[34] = {{id = 1706, cost = 12000},{id = 6064, cost = 12000, requiredIds = {6063}},{id = 10880, cost = 12000, requiredIds = {2010}},{id = 8105, cost = 12000, requiredIds = {8104}},{id = 2767, cost = 12000, requiredIds = {992}},{id = 19302, cost = 600, requiredIds = {19299}, race = 4},{id = 19240, cost = 600, requiredIds = {19238}, races = {1, 3}},},
	[36] = {{id = 988, cost = 14000, requiredIds = {527}},{id = 2791, cost = 14000, requiredIds = {1245}},{id = 6066, cost = 14000, requiredIds = {6065}},{id = 15264, cost = 14000, requiredIds = {15263}},{id = 15431, cost = 700, requiredIds = {15430}, requiredTalentId = 15237},{id = 19277, cost = 700, requiredIds = {19276}, race = 5},{id = 17312, cost = 700, requiredIds = {17311}, requiredTalentId = 15407},{id = 8192, cost = 14000, requiredIds = {453}},{id = 19309, cost = 700, requiredIds = {19308}, race = 8},},
	[38] = {{id = 9474, cost = 16000, requiredIds = {9473}},{id = 6078, cost = 16000, requiredIds = {6077}},{id = 6060, cost = 16000, requiredIds = {1004}},},
	[40] = {{id = 14818, cost = 900, requiredIds = {14752}, requiredTalentId = 14752},{id = 1006, cost = 18000, requiredIds = {602}},{id = 10874, cost = 18000, requiredIds = {8131}},{id = 9485, cost = 18000, requiredIds = {9484}},{id = 2060, cost = 18000},{id = 996, cost = 18000, requiredIds = {596}},{id = 9592, cost = 18000, requiredIds = {9579}},{id = 8106, cost = 18000, requiredIds = {8105}},{id = 19264, cost = 900, requiredIds = {19262}, races = {5, 10}},{id = 44044, cost = 900, requiredIds = {44043}, races = {3, 11}},{id = 19283, cost = 900, requiredIds = {19282}, race = 8},{id = 19273, cost = 900, requiredIds = {19271}, race = 1},},
	[42] = {{id = 10898, cost = 22000, requiredIds = {6066}},{id = 15265, cost = 22000, requiredIds = {15264}},{id = 10888, cost = 22000, requiredIds = {8124}},{id = 10957, cost = 22000, requiredIds = {976}},{id = 10892, cost = 22000, requiredIds = {2767}},{id = 19303, cost = 1100, requiredIds = {19302}, race = 4},{id = 19241, cost = 1100, requiredIds = {19240}, races = {1, 3}},},
	[44] = {{id = 10915, cost = 24000, requiredIds = {9474}},{id = 27799, cost = 1200, requiredIds = {15431}, requiredTalentId = 15237},{id = 10927, cost = 24000, requiredIds = {6078}},{id = 19278, cost = 1200, requiredIds = {19277}, race = 5},{id = 10911, cost = 24000, requiredIds = {605}},{id = 17313, cost = 1200, requiredIds = {17312}, requiredTalentId = 15407},{id = 10909, cost = 24000, requiredIds = {2096}},{id = 19310, cost = 1200, requiredIds = {19309}, race = 8},},
	[46] = {{id = 10963, cost = 26000, requiredIds = {2060}},{id = 10881, cost = 26000, requiredIds = {10880}},{id = 10933, cost = 26000, requiredIds = {6060}},{id = 10945, cost = 26000, requiredIds = {8106}},},
	[48] = {{id = 10875, cost = 28000, requiredIds = {10874}},{id = 10937, cost = 28000, requiredIds = {2791}},{id = 10899, cost = 28000, requiredIds = {10898}},{id = 21562, cost = 28000, requiredIds = {10937}},{id = 15266, cost = 28000, requiredIds = {15265}},},
	[50] = {{id = 14819, cost = 1500, requiredIds = {14818}, requiredTalentId = 14752},{id = 10951, cost = 30000, requiredIds = {1006}},{id = 10916, cost = 30000, requiredIds = {10915}},{id = 27870, cost = 1200, requiredIds = {724}, requiredTalentId = 724},{id = 10960, cost = 30000, requiredIds = {996}},{id = 10928, cost = 30000, requiredIds = {10927}},{id = 10941, cost = 30000, requiredIds = {9592}},{id = 10893, cost = 30000, requiredIds = {10892}},{id = 19265, cost = 1500, requiredIds = {19264}, races = {5, 10}},{id = 44045, cost = 1500, requiredIds = {44044}, races = {3, 11}},{id = 19304, cost = 1500, requiredIds = {19303}, race = 4},{id = 19284, cost = 1500, requiredIds = {19283}, race = 8},{id = 19242, cost = 1500, requiredIds = {19241}, races = {1, 3}},{id = 19274, cost = 1500, requiredIds = {19273}, race = 1},},
	[52] = {{id = 10964, cost = 38000, requiredIds = {10963}},{id = 27800, cost = 1900, requiredIds = {27799}, requiredTalentId = 15237},{id = 19279, cost = 1900, requiredIds = {19278}, race = 5},{id = 10946, cost = 38000, requiredIds = {10945}},{id = 17314, cost = 1900, requiredIds = {17313}, requiredTalentId = 15407},{id = 10953, cost = 38000, requiredIds = {8192}},{id = 19311, cost = 1900, requiredIds = {19310}, race = 8},},
	[54] = {{id = 10900, cost = 40000, requiredIds = {10899}},{id = 15267, cost = 40000, requiredIds = {15266}},{id = 10934, cost = 40000, requiredIds = {10933}},},
	[56] = {{id = 10876, cost = 42000, requiredIds = {10875}},{id = 34863, cost = 2100, requiredIds = {34861}, requiredTalentId = 34861},{id = 10917, cost = 42000, requiredIds = {10916}},{id = 10929, cost = 42000, requiredIds = {10928}},{id = 27683, cost = 42000, requiredIds = {10958}},{id = 10890, cost = 42000, requiredIds = {10888}},{id = 10958, cost = 42000, requiredIds = {10957}},},
	[58] = {{id = 10965, cost = 44000, requiredIds = {10964}},{id = 20770, cost = 44000, requiredIds = {10881}},{id = 10947, cost = 44000, requiredIds = {10946}},{id = 10912, cost = 44000, requiredIds = {10911}},{id = 10894, cost = 44000, requiredIds = {10893}},{id = 19305, cost = 2200, requiredIds = {19304}, race = 4},{id = 19243, cost = 2200, requiredIds = {19242}, races = {1, 3}},},
	[60] = {{id = 27841, cost = 2300, requiredIds = {14819}, requiredTalentId = 14752},{id = 10952, cost = 46000, requiredIds = {10951}},{id = 10938, cost = 46000, requiredIds = {10937}},{id = 10901, cost = 46000, requiredIds = {10900}},{id = 21564, cost = 46000, requiredIds = {21562}},{id = 27681, cost = 2300, requiredIds = {27841}, requiredTalentId = 14752},{id = 10955, cost = 46000, requiredIds = {9485}},{id = 34864, cost = 2300, requiredIds = {34863}, requiredTalentId = 34861},{id = 25314, cost = 65000, requiredIds = {10965}},{id = 15261, cost = 46000, requiredIds = {15267}},{id = 27801, cost = 2300, requiredIds = {27800}, requiredTalentId = 15237},{id = 27871, cost = 1500, requiredIds = {27870}, requiredTalentId = 724},{id = 10961, cost = 46000, requiredIds = {10960}},{id = 25316, cost = 6500, requiredIds = {10961}},{id = 25315, cost = 6500, requiredIds = {10929}},{id = 19280, cost = 2300, requiredIds = {19279}, race = 5},{id = 10942, cost = 46000, requiredIds = {10941}},{id = 18807, cost = 2300, requiredIds = {17314}, requiredTalentId = 15407},{id = 19266, cost = 2300, requiredIds = {19265}, races = {5, 10}},{id = 34916, cost = 2300, requiredIds = {34914}, requiredTalentId = 34914},{id = 44046, cost = 2300, requiredIds = {44045}, races = {3, 11}},{id = 19285, cost = 2300, requiredIds = {19284}, race = 8},{id = 19312, cost = 2300, requiredIds = {19311}, race = 8},{id = 19275, cost = 2300, requiredIds = {19274}, race = 1},},
	[61] = {{id = 25233, cost = 53000, requiredIds = {10917}},{id = 25363, cost = 53000, requiredIds = {10934}},},
	[62] = {{id = 32379, cost = 59000},},
	[63] = {{id = 25379, cost = 65000, requiredIds = {10876}},{id = 25210, cost = 65000, requiredIds = {25314}},{id = 25372, cost = 65000, requiredIds = {10947}},},
	[64] = {{id = 32546, cost = 72000},},
	[65] = {{id = 25217, cost = 80000, requiredIds = {10901}},{id = 34865, cost = 2300, requiredIds = {34864}, requiredTalentId = 34861},{id = 25221, cost = 80000, requiredIds = {25315}},{id = 25367, cost = 80000, requiredIds = {10894}},},
	[66] = {{id = 25384, cost = 65000, requiredIds = {15261}},{id = 25429, cost = 89000, requiredIds = {10942}},{id = 34433, cost = 89000},{id = 25446, cost = 6500, requiredIds = {19305}, race = 4},{id = 25437, cost = 6500, requiredIds = {19243}, races = {1, 3}},},
	[67] = {{id = 25235, cost = 99000, requiredIds = {25233}},{id = 25596, cost = 99000, requiredIds = {10953}},},
	[68] = {{id = 25213, cost = 110000, requiredIds = {25210}},{id = 25331, cost = 3250, requiredIds = {27801}, requiredTalentId = 15237},{id = 25308, cost = 110000, requiredIds = {25316}},{id = 33076, cost = 110000},{id = 25435, cost = 110000, requiredIds = {20770}},{id = 25467, cost = 6500, requiredIds = {19280}, race = 5},{id = 25387, cost = 6500, requiredIds = {18807}, requiredTalentId = 15407},{id = 25433, cost = 110000, requiredIds = {10958}},{id = 25477, cost = 6500, requiredIds = {19312}, race = 8},},
	[69] = {{id = 25431, cost = 65000, requiredIds = {10952}},{id = 25364, cost = 65000, requiredIds = {25363}},{id = 25375, cost = 65000, requiredIds = {25372}},},
	[70] = {{id = 25312, cost = 2300, requiredIds = {27841}, requiredTalentId = 14752},{id = 25380, cost = 110000, requiredIds = {25379}},{id = 32375, cost = 110000, requiredIds = {988}},{id = 25389, cost = 65000, requiredIds = {10938}},{id = 25218, cost = 140000, requiredIds = {25217}},{id = 32999, cost = 3400, requiredIds = {25312}, requiredTalentId = 14752},{id = 34866, cost = 2300, requiredIds = {34865}, requiredTalentId = 34861},{id = 28275, cost = 1500, requiredIds = {27871}, requiredTalentId = 724},{id = 25222, cost = 140000, requiredIds = {25221}},{id = 32996, cost = 110000, requiredIds = {32379}},{id = 25368, cost = 140000, requiredIds = {25367}},{id = 25461, cost = 6500, requiredIds = {19266}, races = {5, 10}},{id = 34917, cost = 2300, requiredIds = {34916}, requiredTalentId = 34914},{id = 44047, cost = 3250, requiredIds = {44046}, races = {3, 11}},{id = 25470, cost = 6500, requiredIds = {19285}, race = 8},{id = 25441, cost = 6500, requiredIds = {19275}, race = 1},},
}

-- ROGUE
-- ordered by rank
local backstab = {53,2589,2590,2591,8721,11279,11280,11281,25300,26863}
local kidneyShot = {408,8643}
local garrote = {703,8631,8632,8633,11289,11290,26839,26884}
local sinisterStrike = {1752,1757,1758,1759,1760,8621,11293,11294,26861,26862}
local kick = {1766,1767,1768,1769,38768}
local gouge = {1776,1777,8629,11285,11286,38764}
local stealth = {1784,1785,1786,1787}
local vanish = {1856,1857,26889}
local rupture = {1943,8639,8640,11273,11274,11275,26867}
local feint = {1966,6768,8637,11303,25302,27448}
local sap = {6770,2070,11297}
local eviscerate = {2098,6760,6761,6762,8623,8624,11299,11300,31016,26865}
local deadlyPoison = {2835}
local sprint = {2983,8696,11305}
local cripplingPoison = {3420}
local sliceandDice = {5171,6774}
local evasion = {5277,26669}
local mindnumbingPoison = {5763}
local exposeArmor = {8647,8649,8650,11197,11198,26866}
local ambush = {8676,8724,8725,11267,11268,11269,27441}
local instantPoison = {8681}
local envenom = {32645,32684}
local mutilate = {1329,34411,34412,34413}
Data.overriddenByClass.ROGUE = {backstab,kidneyShot,garrote,sinisterStrike,kick,gouge,stealth,vanish,rupture,feint,sap,eviscerate,deadlyPoison,sprint,cripplingPoison,sliceandDice,evasion,mindnumbingPoison,exposeArmor,ambush,instantPoison,envenom,mutilate}
Data.spellsByClass.ROGUE = {
	[1] = {{id = 1784, cost = 10},},
	[4] = {{id = 53, cost = 100},{id = 921, cost = 100},},
	[6] = {{id = 1776, cost = 100},{id = 1757, cost = 100},},
	[8] = {{id = 6760, cost = 200, requiredIds = {2098}},{id = 5277, cost = 200},},
	[10] = {{id = 5171, cost = 300},{id = 2983, cost = 300},{id = 674, cost = 300},{id = 6770, cost = 300},},
	[12] = {{id = 2589, cost = 800, requiredIds = {53}},{id = 1766, cost = 800},{id = 3127, cost = 800},},
	[14] = {{id = 8647, cost = 1200},{id = 703, cost = 1200},{id = 1758, cost = 1200, requiredIds = {1757}},},
	[16] = {{id = 6761, cost = 1800, requiredIds = {6760}},{id = 1966, cost = 1800},{id = 1804, cost = 1800},},
	[18] = {{id = 8676, cost = 2900},{id = 1777, cost = 2900, requiredIds = {1776}},},
	[20] = {{id = 1943, cost = 3000},{id = 2590, cost = 3000, requiredIds = {2589}},{id = 3420, cost = 3000},{id = 1785, cost = 3000, requiredIds = {1784}},},
	[22] = {{id = 8631, cost = 4000, requiredIds = {703}},{id = 1759, cost = 4000, requiredIds = {1758}},{id = 1725, cost = 4000},{id = 1856, cost = 4000, requiredIds = {1784}},},
	[24] = {{id = 6762, cost = 5000, requiredIds = {6761}},{id = 5763, cost = 5000},{id = 2836, cost = 5000},},
	[26] = {{id = 8724, cost = 6000, requiredIds = {8676}},{id = 1833, cost = 6000},{id = 8649, cost = 6000, requiredIds = {8647}},{id = 1767, cost = 6000, requiredIds = {1766}},},
	[28] = {{id = 8639, cost = 8000, requiredIds = {1943}},{id = 2591, cost = 8000, requiredIds = {2590}},{id = 6768, cost = 8000, requiredIds = {1966}},{id = 8687, cost = 8000},{id = 2070, cost = 8000, requiredIds = {6770}},},
	[30] = {{id = 8632, cost = 10000, requiredIds = {8631}},{id = 408, cost = 10000},{id = 1760, cost = 10000, requiredIds = {1759}},{id = 2835, cost = 10000},{id = 1842, cost = 10000, requiredIds = {2836}},},
	[32] = {{id = 8623, cost = 12000, requiredIds = {6762}},{id = 8629, cost = 12000, requiredIds = {1777}},{id = 13220, cost = 12000},},
	[34] = {{id = 8725, cost = 14000, requiredIds = {8724}},{id = 8696, cost = 14000, requiredIds = {2983}},{id = 2094, cost = 14000},},
	[36] = {{id = 8650, cost = 16000, requiredIds = {8649}},{id = 8640, cost = 16000, requiredIds = {8639}},{id = 8721, cost = 16000, requiredIds = {2591}},{id = 8691, cost = 16000},},
	[38] = {{id = 8633, cost = 18000, requiredIds = {8632}},{id = 8621, cost = 18000, requiredIds = {1760}},{id = 2837, cost = 18000},{id = 8694, cost = 18000},},
	[40] = {{id = 8624, cost = 20000, requiredIds = {8623}},{id = 8637, cost = 20000, requiredIds = {6768}},{id = 13228, cost = 20000},{id = 1860, cost = 20000},{id = 1786, cost = 20000, requiredIds = {1785}},},
	[42] = {{id = 11267, cost = 27000, requiredIds = {8725}},{id = 6774, cost = 27000, requiredIds = {5171}},{id = 1768, cost = 27000, requiredIds = {1767}},{id = 1857, cost = 27000, requiredIds = {1856}},},
	[44] = {{id = 11273, cost = 29000, requiredIds = {8640}},{id = 11279, cost = 29000, requiredIds = {8721}},{id = 11341, cost = 29000},},
	[46] = {{id = 11197, cost = 31000, requiredIds = {8650}},{id = 11289, cost = 31000, requiredIds = {8633}},{id = 11285, cost = 31000, requiredIds = {8629}},{id = 11293, cost = 31000, requiredIds = {8621}},{id = 11357, cost = 31000},{id = 17347, cost = 384, requiredIds = {16511}, requiredTalentId = 16511},},
	[48] = {{id = 11299, cost = 33000, requiredIds = {8624}},{id = 13229, cost = 33000},{id = 11297, cost = 33000, requiredIds = {2070}},},
	[50] = {{id = 11268, cost = 35000, requiredIds = {11267}},{id = 8643, cost = 35000, requiredIds = {408}},{id = 34411, cost = 5500, requiredIds = {1329}, requiredTalentId = 1329},{id = 26669, cost = 35000, requiredIds = {5277}},{id = 3421, cost = 35000},},
	[52] = {{id = 11274, cost = 46000, requiredIds = {11273}},{id = 11280, cost = 46000, requiredIds = {11279}},{id = 11303, cost = 46000, requiredIds = {8637}},{id = 11342, cost = 46000},{id = 11400, cost = 46000},},
	[54] = {{id = 11290, cost = 48000, requiredIds = {11289}},{id = 11294, cost = 48000, requiredIds = {11293}},{id = 11358, cost = 48000},},
	[56] = {{id = 11300, cost = 50000, requiredIds = {11299}},{id = 11198, cost = 50000, requiredIds = {11197}},{id = 13230, cost = 50000},},
	[58] = {{id = 11269, cost = 52000, requiredIds = {11268}},{id = 1769, cost = 52000, requiredIds = {1768}},{id = 11305, cost = 52000, requiredIds = {8696}},{id = 17348, cost = 650, requiredIds = {17347}, requiredTalentId = 16511},},
	[60] = {{id = 31016, cost = 65000, requiredIds = {11300}},{id = 34412, cost = 6500, requiredIds = {34411}, requiredTalentId = 1329},{id = 11275, cost = 54000, requiredIds = {11274}},{id = 11281, cost = 54000, requiredIds = {11280}},{id = 25300, cost = 54000, requiredIds = {11281}},{id = 25302, cost = 50000, requiredIds = {11303}},{id = 11286, cost = 54000, requiredIds = {11285}},{id = 25347, cost = 54000},{id = 11343, cost = 54000},{id = 1787, cost = 54000, requiredIds = {1786}},},
	[61] = {{id = 26839, cost = 50000, requiredIds = {11290}},},
	[62] = {{id = 32645, cost = 59000},{id = 26861, cost = 50000, requiredIds = {11294}},{id = 26969, cost = 65000},{id = 26889, cost = 59000, requiredIds = {1857}},},
	[64] = {{id = 26679, cost = 72000},{id = 26865, cost = 140000, requiredIds = {31016}},{id = 27448, cost = 72000, requiredIds = {25302}},{id = 27283, cost = 80000},},
	[66] = {{id = 27441, cost = 80000, requiredIds = {11269}},{id = 26866, cost = 99000, requiredIds = {11198}},{id = 31224, cost = 89000},},
	[67] = {{id = 38764, cost = 99000, requiredIds = {11286}},},
	[68] = {{id = 26867, cost = 120000, requiredIds = {11275}},{id = 26863, cost = 110000, requiredIds = {25300}},{id = 26892, cost = 110000},{id = 26786, cost = 110000},},
	[69] = {{id = 32684, cost = 120000, requiredIds = {32645}},{id = 38768, cost = 120000, requiredIds = {1769}},},
	[70] = {{id = 26884, cost = 140000, requiredIds = {26839}},{id = 34413, cost = 7500, requiredIds = {34412}, requiredTalentId = 1329},{id = 5938, cost = 140000},{id = 26862, cost = 140000, requiredIds = {26861}},{id = 27282, cost = 140000},{id = 26864, cost = 2700, requiredIds = {17348}, requiredTalentId = 16511},},
}

-- SHAMAN
Data.spellsByClass.SHAMAN = {
	[1] = {{id = 8017, cost = 10},},
	[4] = {{id = 8042, cost = 100},},
	[6] = {{id = 2484, cost = 100},{id = 332, cost = 100, requiredIds = {331}},},
	[8] = {{id = 8044, cost = 100, requiredIds = {8042}},{id = 529, cost = 100, requiredIds = {403}},{id = 5730, cost = 100},{id = 324, cost = 100},{id = 8018, cost = 100, requiredIds = {8017}},},
	[10] = {{id = 8050, cost = 400},{id = 8024, cost = 400},{id = 8075, cost = 400},},
	[12] = {{id = 1535, cost = 800},{id = 370, cost = 800},{id = 2008, cost = 800},{id = 547, cost = 800, requiredIds = {332}},},
	[14] = {{id = 8045, cost = 900, requiredIds = {8044}},{id = 548, cost = 900, requiredIds = {529}},{id = 8154, cost = 900, requiredIds = {8071}},},
	[16] = {{id = 325, cost = 1800, requiredIds = {324}},{id = 8019, cost = 1800, requiredIds = {8018}},{id = 526, cost = 1800},},
	[18] = {{id = 8052, cost = 2000, requiredIds = {8050}},{id = 6390, cost = 2000, requiredIds = {5730}},{id = 8027, cost = 2000, requiredIds = {8024}},{id = 913, cost = 2000, requiredIds = {547}},{id = 8143, cost = 2000},},
	[20] = {{id = 8056, cost = 2200},{id = 915, cost = 2200, requiredIds = {548}},{id = 6363, cost = 2200, requiredIds = {3599}},{id = 8033, cost = 2200},{id = 2645, cost = 2200},{id = 8004, cost = 2200},},
	[22] = {{id = 8498, cost = 3000, requiredIds = {1535}},{id = 131, cost = 3000},{id = 2870, cost = 3000},{id = 8166, cost = 3000},},
	[24] = {{id = 8046, cost = 3500, requiredIds = {8045}},{id = 8181, cost = 3500},{id = 905, cost = 3500, requiredIds = {325}},{id = 10399, cost = 3500, requiredIds = {8019}},{id = 8155, cost = 3500, requiredIds = {8154}},{id = 8160, cost = 3500, requiredIds = {8075}},{id = 20609, cost = 3500, requiredIds = {2008}},{id = 939, cost = 3500, requiredIds = {913}},},
	[26] = {{id = 943, cost = 4000, requiredIds = {915}},{id = 8190, cost = 4000},{id = 6196, cost = 4000},{id = 8030, cost = 4000, requiredIds = {8027}},{id = 5675, cost = 4000},},
	[28] = {{id = 8053, cost = 6000, requiredIds = {8052}},{id = 6391, cost = 6000, requiredIds = {6390}},{id = 8184, cost = 6000},{id = 8227, cost = 6000},{id = 8038, cost = 6000, requiredIds = {8033}},{id = 546, cost = 6000},{id = 8008, cost = 6000, requiredIds = {8004}},},
	[30] = {{id = 6364, cost = 7000, requiredIds = {6363}},{id = 556, cost = 7000},{id = 8177, cost = 7000},{id = 10595, cost = 7000},{id = 8232, cost = 7000},{id = 6375, cost = 7000, requiredIds = {5394}},{id = 20608, cost = 7000},{id = 36936, cost = 7000},},
	[32] = {{id = 421, cost = 8000},{id = 8499, cost = 8000, requiredIds = {8498}},{id = 6041, cost = 8000, requiredIds = {943}},{id = 8012, cost = 8000, requiredIds = {370}},{id = 945, cost = 8000, requiredIds = {905}},{id = 8512, cost = 8000},{id = 959, cost = 8000, requiredIds = {939}},},
	[34] = {{id = 8058, cost = 9000, requiredIds = {8056}},{id = 16314, cost = 9000, requiredIds = {10399}},{id = 6495, cost = 9000},{id = 10406, cost = 9000, requiredIds = {8155}},},
	[36] = {{id = 10412, cost = 10000, requiredIds = {8046}},{id = 10585, cost = 10000, requiredIds = {8190}},{id = 16339, cost = 10000, requiredIds = {8030}},{id = 15107, cost = 10000},{id = 20610, cost = 10000, requiredIds = {20609}},{id = 8010, cost = 10000, requiredIds = {8008}},{id = 10495, cost = 10000, requiredIds = {5675}},},
	[38] = {{id = 10391, cost = 11000, requiredIds = {6041}},{id = 6392, cost = 11000, requiredIds = {6391}},{id = 8249, cost = 11000, requiredIds = {8227}},{id = 10478, cost = 11000, requiredIds = {8181}},{id = 10456, cost = 11000, requiredIds = {8038}},{id = 8161, cost = 11000, requiredIds = {8160}},{id = 8170, cost = 11000},},
	[40] = {{id = 930, cost = 12000, requiredIds = {421}},{id = 10447, cost = 12000, requiredIds = {8053}},{id = 6365, cost = 12000, requiredIds = {6364}},{id = 8134, cost = 12000, requiredIds = {945}},{id = 8235, cost = 12000, requiredIds = {8232}},{id = 8737, cost = 12000},{id = 1064, cost = 12000},{id = 6377, cost = 12000, requiredIds = {6375}},{id = 8005, cost = 12000, requiredIds = {959}},},
	[42] = {{id = 11314, cost = 16000, requiredIds = {8499}},{id = 10537, cost = 16000, requiredIds = {8184}},{id = 8835, cost = 16000},{id = 10613, cost = 16000, requiredIds = {8512}},},
	[44] = {{id = 10392, cost = 18000, requiredIds = {10391}},{id = 10600, cost = 18000, requiredIds = {10595}},{id = 16315, cost = 18000, requiredIds = {16314}},{id = 10407, cost = 18000, requiredIds = {10406}},{id = 10466, cost = 18000, requiredIds = {8010}},},
	[46] = {{id = 10472, cost = 20000, requiredIds = {8058}},{id = 10586, cost = 20000, requiredIds = {10585}},{id = 16341, cost = 20000, requiredIds = {16339}},{id = 15111, cost = 20000, requiredIds = {15107}},{id = 10622, cost = 20000, requiredIds = {1064}},{id = 10496, cost = 20000, requiredIds = {10495}},},
	[48] = {{id = 2860, cost = 22000, requiredIds = {930}},{id = 10413, cost = 22000, requiredIds = {10412}},{id = 10427, cost = 22000, requiredIds = {6392}},{id = 10526, cost = 22000, requiredIds = {8249}},{id = 16355, cost = 22000, requiredIds = {10456}},{id = 10431, cost = 22000, requiredIds = {8134}},{id = 20776, cost = 22000, requiredIds = {20610}},{id = 10395, cost = 22000, requiredIds = {8005}},},
	[50] = {{id = 15207, cost = 24000, requiredIds = {10392}},{id = 10437, cost = 24000, requiredIds = {6365}},{id = 10486, cost = 24000, requiredIds = {8235}},{id = 10462, cost = 24000, requiredIds = {6377}},{id = 25908, cost = 24000},},
	[52] = {{id = 11315, cost = 27000, requiredIds = {11314}},{id = 10448, cost = 27000, requiredIds = {10447}},{id = 10442, cost = 27000, requiredIds = {8161}},{id = 10614, cost = 27000, requiredIds = {10613}},{id = 10467, cost = 27000, requiredIds = {10466}},},
	[54] = {{id = 10479, cost = 29000, requiredIds = {10478}},{id = 16316, cost = 29000, requiredIds = {16315}},{id = 10408, cost = 29000, requiredIds = {10407}},{id = 10623, cost = 29000, requiredIds = {10622}},},
	[56] = {{id = 10605, cost = 30000, requiredIds = {2860}},{id = 15208, cost = 30000, requiredIds = {15207}},{id = 10587, cost = 30000, requiredIds = {10586}},{id = 16342, cost = 30000, requiredIds = {16341}},{id = 10627, cost = 30000, requiredIds = {8835}},{id = 10432, cost = 30000, requiredIds = {10431}},{id = 15112, cost = 30000, requiredIds = {15111}},{id = 10396, cost = 30000, requiredIds = {10395}},{id = 10497, cost = 30000, requiredIds = {10496}},},
	[58] = {{id = 10473, cost = 32000, requiredIds = {10472}},{id = 10428, cost = 32000, requiredIds = {10427}},{id = 10538, cost = 32000, requiredIds = {10537}},{id = 16387, cost = 32000, requiredIds = {10526}},{id = 16356, cost = 32000, requiredIds = {16355}},},
	[60] = {{id = 10414, cost = 34000, requiredIds = {10413}},{id = 29228, cost = 65000, requiredIds = {10448}},{id = 10438, cost = 34000, requiredIds = {10437}},{id = 25359, cost = 65000, requiredIds = {10627}},{id = 10601, cost = 34000, requiredIds = {10600}},{id = 25361, cost = 34000, requiredIds = {10442}},{id = 16362, cost = 34000, requiredIds = {10486}},{id = 20777, cost = 34000, requiredIds = {20776}},{id = 32593, cost = 1700, requiredIds = {974}, requiredTalentId = 974},{id = 10463, cost = 34000, requiredIds = {10462}},{id = 25357, cost = 6500, requiredIds = {10396}},{id = 10468, cost = 34000, requiredIds = {10467}},},
	[61] = {{id = 25546, cost = 34000, requiredIds = {11315}},{id = 25585, cost = 34000, requiredIds = {10614}},{id = 25422, cost = 34000, requiredIds = {10623}},},
	[62] = {{id = 25448, cost = 38000, requiredIds = {15208}},{id = 25479, cost = 38000, requiredIds = {16316}},{id = 24398, cost = 38000},},
	[63] = {{id = 25439, cost = 42000, requiredIds = {10605}},{id = 25469, cost = 42000, requiredIds = {10432}},{id = 25508, cost = 42000, requiredIds = {10408}},{id = 25391, cost = 42000, requiredIds = {25357}},},
	[64] = {{id = 25489, cost = 47000, requiredIds = {16342}},{id = 3738, cost = 47000},},
	[65] = {{id = 25552, cost = 52000, requiredIds = {10587}},{id = 25528, cost = 52000, requiredIds = {25361}},{id = 25577, cost = 52000, requiredIds = {15112}},{id = 25570, cost = 52000, requiredIds = {10497}},},
	[66] = {{id = 2062, cost = 58000},{id = 25500, cost = 58000, requiredIds = {16356}},{id = 25420, cost = 58000, requiredIds = {10468}},},
	[67] = {{id = 25449, cost = 64000, requiredIds = {25448}},{id = 25525, cost = 64000, requiredIds = {10428}},{id = 25557, cost = 64000, requiredIds = {16387}},{id = 25560, cost = 64000, requiredIds = {10479}},},
	[68] = {{id = 2894, cost = 71000},{id = 25464, cost = 71000, requiredIds = {10473}},{id = 25563, cost = 71000, requiredIds = {10538}},{id = 25505, cost = 71000, requiredIds = {16362}},{id = 25423, cost = 71000, requiredIds = {25422}},},
	[69] = {{id = 25454, cost = 79000, requiredIds = {10414}},{id = 25533, cost = 79000, requiredIds = {10438}},{id = 25574, cost = 79000, requiredIds = {10601}},{id = 25567, cost = 79000, requiredIds = {10463}},{id = 33736, cost = 79000, requiredIds = {24398}},},
	[70] = {{id = 25442, cost = 88000, requiredIds = {25439}},{id = 25547, cost = 88000, requiredIds = {25546}},{id = 25457, cost = 88000, requiredIds = {29228}},{id = 2825, cost = 88000, faction = "Horde"},{id = 32182, cost = 88000, faction = "Alliance"},{id = 25472, cost = 88000, requiredIds = {25469}},{id = 25485, cost = 88000, requiredIds = {25479}},{id = 25509, cost = 88000, requiredIds = {25508}},{id = 25587, cost = 88000, requiredIds = {25585}},{id = 32594, cost = 2500, requiredIds = {32593}, requiredTalentId = 974},{id = 25396, cost = 88000, requiredIds = {25391}},},
}

-- WARLOCK
Data.spellsByClass.WARLOCK = {
	[1] = {{id = 348, cost = 10},},
	[4] = {{id = 172, cost = 100},{id = 702, cost = 100},},
	[6] = {{id = 1454, cost = 100},{id = 695, cost = 100, requiredIds = {686}},},
	[8] = {{id = 980, cost = 200},{id = 5782, cost = 200},},
	[10] = {{id = 1120, cost = 300},{id = 6201, cost = 300, requiredIds = {1120}},{id = 696, cost = 300, requiredIds = {687}},{id = 707, cost = 300, requiredIds = {348}},},
	[12] = {{id = 1108, cost = 600, requiredIds = {702}},{id = 755, cost = 600},{id = 705, cost = 600, requiredIds = {695}},},
	[14] = {{id = 6222, cost = 900, requiredIds = {172}},{id = 704, cost = 900},{id = 689, cost = 900},},
	[16] = {{id = 1455, cost = 1080, requiredIds = {1454}},{id = 5697, cost = 1200},},
	[18] = {{id = 1014, cost = 1500, requiredIds = {980}},{id = 693, cost = 1500, requiredIds = {1120}},{id = 5676, cost = 1500},},
	[20] = {{id = 706, cost = 2000},{id = 3698, cost = 2000, requiredIds = {755}},{id = 698, cost = 2000},{id = 1094, cost = 2000, requiredIds = {707}},{id = 5740, cost = 2000},{id = 1088, cost = 2000, requiredIds = {705}},},
	[22] = {{id = 6205, cost = 2500, requiredIds = {1108}},{id = 699, cost = 2500, requiredIds = {689}},{id = 6202, cost = 2500, requiredIds = {6201}},{id = 126, cost = 2500},},
	[24] = {{id = 6223, cost = 3000, requiredIds = {6222}},{id = 5138, cost = 3000},{id = 8288, cost = 3000, requiredIds = {1120}},{id = 5500, cost = 3000},{id = 18867, cost = 150, requiredIds = {17877}, requiredTalentId = 17877},},
	[26] = {{id = 1714, cost = 4000},{id = 1456, cost = 3600, requiredIds = {1455}},{id = 132, cost = 4000},{id = 17919, cost = 4000, requiredIds = {5676}},},
	[28] = {{id = 6217, cost = 5000, requiredIds = {1014}},{id = 7658, cost = 5000, requiredIds = {704}},{id = 710, cost = 5000},{id = 6366, cost = 5000},{id = 3699, cost = 5000, requiredIds = {3698}},{id = 1106, cost = 5000, requiredIds = {1088}},},
	[30] = {{id = 709, cost = 6000, requiredIds = {699}},{id = 20752, cost = 6000, requiredIds = {693}},{id = 1086, cost = 6000, requiredIds = {706}},{id = 1098, cost = 6000},{id = 5784, cost = 10000},{id = 1949, cost = 6000},{id = 2941, cost = 6000, requiredIds = {1094}},},
	[32] = {{id = 7646, cost = 7000, requiredIds = {6205}},{id = 1490, cost = 7000},{id = 6213, cost = 7000, requiredIds = {5782}},{id = 6229, cost = 7000},{id = 18868, cost = 350, requiredIds = {18867}, requiredTalentId = 17877},},
	[34] = {{id = 7648, cost = 8000, requiredIds = {6223}},{id = 6226, cost = 8000, requiredIds = {5138}},{id = 5699, cost = 8000, requiredIds = {6202}},{id = 6219, cost = 8000, requiredIds = {5740}},{id = 17920, cost = 8000, requiredIds = {17919}},},
	[36] = {{id = 11687, cost = 8100, requiredIds = {1456}},{id = 17951, cost = 9000, requiredIds = {6366}},{id = 2362, cost = 9000, requiredIds = {1120}},{id = 3700, cost = 9000, requiredIds = {3699}},{id = 7641, cost = 9000, requiredIds = {1106}},},
	[38] = {{id = 11711, cost = 10000, requiredIds = {6217}},{id = 7651, cost = 10000, requiredIds = {709}},{id = 8289, cost = 10000, requiredIds = {8288}},{id = 18879, cost = 500, requiredIds = {18265}, requiredTalentId = 18265},},
	[40] = {{id = 5484, cost = 11000},{id = 20755, cost = 11000, requiredIds = {20752}},{id = 11733, cost = 11000, requiredIds = {1086}},{id = 11665, cost = 11000, requiredIds = {2941}},{id = 18869, cost = 550, requiredIds = {18868}, requiredTalentId = 17877},},
	[42] = {{id = 7659, cost = 11000, requiredIds = {7658}},{id = 11707, cost = 11000, requiredIds = {7646}},{id = 6789, cost = 11000},{id = 11739, cost = 11000, requiredIds = {6229}},{id = 11683, cost = 11000, requiredIds = {1949}},{id = 17921, cost = 11000, requiredIds = {17920}},},
	[44] = {{id = 11671, cost = 12000, requiredIds = {7648}},{id = 11703, cost = 12000, requiredIds = {6226}},{id = 11725, cost = 12000, requiredIds = {1098}},{id = 11693, cost = 12000, requiredIds = {3700}},{id = 11659, cost = 12000, requiredIds = {7641}},},
	[46] = {{id = 11721, cost = 13000, requiredIds = {1490}},{id = 11699, cost = 13000, requiredIds = {7651}},{id = 11688, cost = 11700, requiredIds = {11687}},{id = 17952, cost = 13000, requiredIds = {17951}},{id = 11729, cost = 13000, requiredIds = {5699}},{id = 11677, cost = 13000, requiredIds = {6219}},},
	[48] = {{id = 11712, cost = 14000, requiredIds = {11711}},{id = 18880, cost = 700, requiredIds = {18879}, requiredTalentId = 18265},{id = 18647, cost = 14000, requiredIds = {710}},{id = 17727, cost = 14000, requiredIds = {2362}},{id = 18930, cost = 700, requiredIds = {17962}, requiredTalentId = 17962},{id = 18870, cost = 700, requiredIds = {18869}, requiredTalentId = 17877},{id = 6353, cost = 14000},},
	[50] = {{id = 11719, cost = 15000, requiredIds = {1714}},{id = 18937, cost = 750, requiredIds = {18220}, requiredTalentId = 18220},{id = 17925, cost = 15000, requiredIds = {6789}},{id = 20756, cost = 15000, requiredIds = {20755}},{id = 11734, cost = 15000, requiredIds = {11733}},{id = 11667, cost = 15000, requiredIds = {11665}},{id = 17922, cost = 15000, requiredIds = {17921}},},
	[52] = {{id = 11708, cost = 18000, requiredIds = {11707}},{id = 11675, cost = 18000, requiredIds = {8289}},{id = 11694, cost = 18000, requiredIds = {11693}},{id = 11740, cost = 18000, requiredIds = {11739}},{id = 11660, cost = 18000, requiredIds = {11659}},},
	[54] = {{id = 11672, cost = 20000, requiredIds = {11671}},{id = 11700, cost = 20000, requiredIds = {11699}},{id = 11704, cost = 20000, requiredIds = {11703}},{id = 17928, cost = 20000, requiredIds = {5484}},{id = 18931, cost = 1000, requiredIds = {18930}, requiredTalentId = 17962},{id = 11684, cost = 20000, requiredIds = {11683}},},
	[56] = {{id = 11717, cost = 22000, requiredIds = {7659}},{id = 6215, cost = 22000, requiredIds = {6213}},{id = 11689, cost = 19800, requiredIds = {11688}},{id = 17953, cost = 22000, requiredIds = {17952}},{id = 18871, cost = 1100, requiredIds = {18870}, requiredTalentId = 17877},{id = 17924, cost = 22000, requiredIds = {6353}},},
	[58] = {{id = 11713, cost = 24000, requiredIds = {11712}},{id = 17926, cost = 24000, requiredIds = {17925}},{id = 18881, cost = 1200, requiredIds = {18880}, requiredTalentId = 18265},{id = 11730, cost = 24000, requiredIds = {11729}},{id = 11726, cost = 24000, requiredIds = {11725}},{id = 11678, cost = 24000, requiredIds = {11677}},{id = 17923, cost = 24000, requiredIds = {17922}},},
	[60] = {{id = 25311, cost = 26000, requiredIds = {11672}},{id = 603, cost = 26000},{id = 11722, cost = 26000, requiredIds = {11721}},{id = 18938, cost = 1300, requiredIds = {18937}, requiredTalentId = 18220},{id = 30404, cost = 2500, requiredIds = {30108}, requiredTalentId = 30108},{id = 20757, cost = 26000, requiredIds = {20756}},{id = 17728, cost = 26000, requiredIds = {17727}},{id = 11735, cost = 26000, requiredIds = {11734}},{id = 11695, cost = 26000, requiredIds = {11694}},{id = 28610, cost = 34000, requiredIds = {11740}},{id = 18932, cost = 1300, requiredIds = {18931}, requiredTalentId = 17962},{id = 11668, cost = 26000, requiredIds = {11667}},{id = 25309, cost = 26000, requiredIds = {11668}},{id = 11661, cost = 26000, requiredIds = {11660}},{id = 30413, cost = 2500, requiredIds = {30283}, requiredTalentId = 30283},},
	[61] = {{id = 27224, cost = 30000, requiredIds = {11708}},},
	[62] = {{id = 27219, cost = 30000, requiredIds = {11700}},{id = 28176, cost = 34000},{id = 25307, cost = 26000, requiredIds = {11661}},},
	[63] = {{id = 27221, cost = 38000, requiredIds = {11704}},{id = 27264, cost = 2500, requiredIds = {18881}, requiredTalentId = 18265},{id = 27263, cost = 1300, requiredIds = {18871}, requiredTalentId = 17877},},
	[64] = {{id = 29722, cost = 42000},{id = 27211, cost = 42000, requiredIds = {17924}},},
	[65] = {{id = 27216, cost = 46000, requiredIds = {25311}},{id = 27266, cost = 2300, requiredIds = {18932}, requiredTalentId = 17962},{id = 27210, cost = 46000, requiredIds = {17923}},},
	[66] = {{id = 27250, cost = 51000, requiredIds = {17953}},{id = 28172, cost = 51000, requiredIds = {17728}},{id = 29858, cost = 51000},},
	[67] = {{id = 27218, cost = 57000, requiredIds = {11713}},{id = 27217, cost = 57000, requiredIds = {11675}},{id = 27259, cost = 57000, requiredIds = {11695}},},
	[68] = {{id = 27223, cost = 63000, requiredIds = {17926}},{id = 27222, cost = 56700, requiredIds = {11689}},{id = 27230, cost = 63000, requiredIds = {11730}},{id = 29893, cost = 63000},{id = 27213, cost = 63000, requiredIds = {11684}},},
	[69] = {{id = 27226, cost = 70000, requiredIds = {11717}},{id = 30909, cost = 70000, requiredIds = {27224}},{id = 27228, cost = 70000, requiredIds = {11722}},{id = 27220, cost = 70000, requiredIds = {27219}},{id = 28189, cost = 70000, requiredIds = {28176}},{id = 27215, cost = 70000, requiredIds = {25309}},{id = 27212, cost = 70000, requiredIds = {11678}},{id = 27209, cost = 70000, requiredIds = {25307}},},
	[70] = {{id = 30910, cost = 78000, requiredIds = {603}},{id = 27265, cost = 1300, requiredIds = {18938}, requiredTalentId = 18220},{id = 30908, cost = 78000, requiredIds = {27221}},{id = 27243, cost = 78000},{id = 30911, cost = 2500, requiredIds = {27264}, requiredTalentId = 18265},{id = 30405, cost = 2500, requiredIds = {30404}, requiredTalentId = 30108},{id = 27238, cost = 78000, requiredIds = {20757}},{id = 27260, cost = 78000, requiredIds = {11735}},{id = 30912, cost = 3900, requiredIds = {27266}, requiredTalentId = 17962},{id = 32231, cost = 78000, requiredIds = {29722}},{id = 30459, cost = 78000, requiredIds = {27210}},{id = 30546, cost = 3900, requiredIds = {27263}, requiredTalentId = 17877},{id = 30414, cost = 2500, requiredIds = {30413}, requiredTalentId = 30283},{id = 30545, cost = 78000, requiredIds = {27211}},},
}

-- WARRIOR
-- ordered by rank
local shieldBash = {72,1671,1672,29704}
local heroicStrike = {78,284,285,1608,11564,11565,11566,11567,25286,29707,30324}
local charge = {100,6178,11578}
local mockingBlow = {694,7400,7402,20559,20560,25266}
local rend = {772,6546,6547,6548,11572,11573,11574,25208}
local cleave = {845,7369,11608,11609,20569,25231}
local demoralizingShout = {1160,6190,11554,11555,11556,25202,25203}
local slam = {1464,8820,11604,11605,25241,25242}
local hamstring = {1715,7372,7373,25212}
local battleShout = {6673,5242,6192,11549,11550,11551,25289,2048}
local execute = {5308,20658,20660,20661,20662,25234,25236}
local thunderClap = {6343,8198,8204,8205,11580,11581,25264}
local pummel = {6552,6554}
local revenge = {6572,6574,7379,11600,11601,25288,25269,30357}
local overpower = {7384,7887,11584,11585}
local sunderArmor = {7386,7405,8380,11596,11597,25225}
local intercept = {20252,20616,20617,25272,25275}
local mortalStrike = {12294,21551,21552,21553,25248,30330}
local devastate = {20243,30016,30022}
local bloodthirst = {23881,23892,23893,23894,25251,30335}
local shieldSlam = {23922,23923,23924,23925,25258,30356}
local rampage = {29801,30030,30033}
Data.overriddenByClass.WARRIOR = {shieldBash,heroicStrike,charge,mockingBlow,rend,cleave,demoralizingShout,slam,hamstring,battleShout,execute,thunderClap,pummel,revenge,overpower,sunderArmor,intercept,mortalStrike,devastate,bloodthirst,shieldSlam,rampage}
Data.spellsByClass.WARRIOR = {
	[1] = {{id = 6673, cost = 10},},
	[4] = {{id = 100, cost = 100},{id = 772, cost = 100},},
	[6] = {{id = 6343, cost = 100},{id = 3127, cost = 100},},
	[8] = {{id = 1715, cost = 200},{id = 284, cost = 200},},
	[10] = {{id = 6546, cost = 600, requiredIds = {772}},{id = 2687, cost = 600},},
	[12] = {{id = 7384, cost = 1000},{id = 5242, cost = 1000, requiredIds = {6673}},{id = 72, cost = 1000},},
	[14] = {{id = 1160, cost = 1500},{id = 6572, cost = 1500, requiredIds = {71}},},
	[16] = {{id = 285, cost = 2000, requiredIds = {284}},{id = 694, cost = 2000},{id = 2565, cost = 2000, requiredIds = {71}},},
	[18] = {{id = 8198, cost = 3000, requiredIds = {6343}},{id = 676, cost = 3000, requiredIds = {71}},},
	[20] = {{id = 6547, cost = 4000, requiredIds = {6546}},{id = 20230, cost = 4000},{id = 674, cost = 4000},{id = 845, cost = 4000},{id = 12678, cost = 4000},},
	[22] = {{id = 6192, cost = 6000, requiredIds = {5242}},{id = 5246, cost = 6000},{id = 7405, cost = 6000},},
	[24] = {{id = 1608, cost = 8000, requiredIds = {285}},{id = 6190, cost = 8000, requiredIds = {1160}},{id = 5308, cost = 8000},{id = 6574, cost = 8000, requiredIds = {6572}},},
	[26] = {{id = 6178, cost = 10000, requiredIds = {100}},{id = 7400, cost = 10000, requiredIds = {694}},{id = 1161, cost = 10000},},
	[28] = {{id = 7887, cost = 11000, requiredIds = {7384}},{id = 8204, cost = 11000, requiredIds = {8198}},{id = 871, cost = 11000, requiredIds = {71}},},
	[30] = {{id = 6548, cost = 12000, requiredIds = {6547}},{id = 7369, cost = 12000, requiredIds = {845}},{id = 1464, cost = 12000},},
	[32] = {{id = 7372, cost = 14000, requiredIds = {1715}},{id = 11564, cost = 14000, requiredIds = {1608}},{id = 11549, cost = 14000, requiredIds = {6192}},{id = 18499, cost = 14000, requiredIds = {2458}},{id = 20658, cost = 14000, requiredIds = {5308}},{id = 1671, cost = 14000, requiredIds = {72}},},
	[34] = {{id = 11554, cost = 16000, requiredIds = {6190}},{id = 7379, cost = 16000, requiredIds = {6574}},{id = 8380, cost = 16000, requiredIds = {7405}},},
	[36] = {{id = 7402, cost = 18000, requiredIds = {7400}},{id = 1680, cost = 18000, requiredIds = {2458}},},
	[38] = {{id = 8205, cost = 20000, requiredIds = {8204}},{id = 6552, cost = 20000, requiredIds = {2458}},{id = 8820, cost = 20000, requiredIds = {1464}},},
	[40] = {{id = 11565, cost = 22000, requiredIds = {11564}},{id = 11572, cost = 22000, requiredIds = {6548}},{id = 11608, cost = 22000, requiredIds = {7369}},{id = 20660, cost = 22000, requiredIds = {20658}},{id = 750, cost = 22000},},
	[42] = {{id = 11550, cost = 32000, requiredIds = {11549}},{id = 20616, cost = 32000},},
	[44] = {{id = 11584, cost = 34000, requiredIds = {7887}},{id = 11555, cost = 34000, requiredIds = {11554}},{id = 11600, cost = 34000, requiredIds = {7379}},},
	[46] = {{id = 11578, cost = 36000, requiredIds = {6178}},{id = 20559, cost = 36000, requiredIds = {7402}},{id = 11604, cost = 36000, requiredIds = {8820}},{id = 11596, cost = 36000, requiredIds = {8380}},},
	[48] = {{id = 11566, cost = 40000, requiredIds = {11565}},{id = 21551, cost = 2000, requiredIds = {12294}, requiredTalentId = 12294},{id = 11580, cost = 40000, requiredIds = {8205}},{id = 23892, cost = 2000, requiredIds = {23881}, requiredTalentId = 23881},{id = 20661, cost = 40000, requiredIds = {20660}},{id = 23923, cost = 2000, requiredIds = {23922}, requiredTalentId = 23922},},
	[50] = {{id = 11573, cost = 42000, requiredIds = {11572}},{id = 11609, cost = 42000, requiredIds = {11608}},{id = 1719, cost = 42000, requiredIds = {2458}},},
	[52] = {{id = 11551, cost = 54000, requiredIds = {11550}},{id = 20617, cost = 54000, requiredIds = {20616}},{id = 1672, cost = 54000, requiredIds = {1671}},},
	[54] = {{id = 7373, cost = 56000, requiredIds = {7372}},{id = 21552, cost = 2800, requiredIds = {21551}, requiredTalentId = 12294},{id = 23893, cost = 2800, requiredIds = {23892}, requiredTalentId = 23881},{id = 11556, cost = 56000, requiredIds = {11555}},{id = 11605, cost = 56000, requiredIds = {11604}},{id = 11601, cost = 56000, requiredIds = {11600}},{id = 23924, cost = 2800, requiredIds = {23923}, requiredTalentId = 23922},},
	[56] = {{id = 11567, cost = 58000, requiredIds = {11566}},{id = 20560, cost = 58000, requiredIds = {20559}},{id = 20662, cost = 58000, requiredIds = {20661}},},
	[58] = {{id = 11581, cost = 60000, requiredIds = {11580}},{id = 6554, cost = 60000, requiredIds = {6552}},{id = 11597, cost = 60000, requiredIds = {11596}},},
	[60] = {{id = 25286, cost = 60000, requiredIds = {11567}},{id = 21553, cost = 3100, requiredIds = {21552}, requiredTalentId = 12294},{id = 11585, cost = 62000, requiredIds = {11584}},{id = 11574, cost = 62000, requiredIds = {11573}},{id = 25289, cost = 65000, requiredIds = {11551}},{id = 23894, cost = 3100, requiredIds = {23893}, requiredTalentId = 23881},{id = 20569, cost = 62000, requiredIds = {11609}},{id = 30030, cost = 3100, requiredIds = {29801}, requiredTalentId = 29801},{id = 30016, cost = 3100, requiredIds = {20243}, requiredTalentId = 20243},{id = 25288, cost = 56000, requiredIds = {11601}},{id = 23925, cost = 3100, requiredIds = {23924}, requiredTalentId = 23922},},
	[61] = {{id = 25272, cost = 65000, requiredIds = {20617}},{id = 25241, cost = 65000, requiredIds = {11605}},},
	[62] = {{id = 25202, cost = 65000, requiredIds = {11556}},{id = 34428, cost = 58000},},
	[63] = {{id = 25269, cost = 65000, requiredIds = {25288}},},
	[64] = {{id = 29704, cost = 60000, requiredIds = {1672}},{id = 23920, cost = 65000},},
	[65] = {{id = 25266, cost = 65000, requiredIds = {20560}},{id = 25234, cost = 65000, requiredIds = {20662}},},
	[66] = {{id = 29707, cost = 65000, requiredIds = {25286}},{id = 25248, cost = 3250, requiredIds = {21553}, requiredTalentId = 12294},{id = 25251, cost = 3250, requiredIds = {23894}, requiredTalentId = 23881},{id = 25258, cost = 3250, requiredIds = {23925}, requiredTalentId = 23922},},
	[67] = {{id = 25212, cost = 65000, requiredIds = {7373}},{id = 25264, cost = 65000, requiredIds = {11581}},{id = 25225, cost = 65000, requiredIds = {11597}},},
	[68] = {{id = 25208, cost = 65000, requiredIds = {11574}},{id = 25231, cost = 65000, requiredIds = {20569}},{id = 469, cost = 65000},},
	[69] = {{id = 2048, cost = 65000, requiredIds = {25289}},{id = 25275, cost = 65000, requiredIds = {25272}},{id = 25242, cost = 65000, requiredIds = {25241}},},
	[70] = {{id = 30330, cost = 3250, requiredIds = {25248}, requiredTalentId = 12294},{id = 30335, cost = 3250, requiredIds = {25251}, requiredTalentId = 23881},{id = 25203, cost = 65000, requiredIds = {25202}},{id = 25236, cost = 65000, requiredIds = {25234}},{id = 30033, cost = 3250, requiredIds = {30030}, requiredTalentId = 29801},{id = 30022, cost = 3250, requiredIds = {30016}, requiredTalentId = 20243},{id = 3411, cost = 65000},{id = 30357, cost = 65000, requiredIds = {25269}},{id = 30356, cost = 3250, requiredIds = {25258}, requiredTalentId = 23922},},
}

return Data
