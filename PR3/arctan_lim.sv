// -----------------------------------------------------------------------------
// Copyright (c) 2018 F.H. Oudman
// -----------------------------------------------------------------------------
// File:		arctan_lim.sv
// Author:	F.H. Oudman
// Mail:		f.h.oudman@student.tue.nl
// -----------------------------------------------------------------------------
// Dependencies:
//  ~ none
// -----------------------------------------------------------------------------
// Type:		function
// Purpose:	Approximate the arctan of a fixed point int, result in degrees.
//				Output is valid for input in the range [0,1).
// -----------------------------------------------------------------------------
// Input:	z
// Output:	arctan_lim
// -----------------------------------------------------------------------------
// Fixed point notation, marked FP, is used in the following manner:
// - two's complement
// - the lower 8 bits represent the fractional part
// -----------------------------------------------------------------------------

`ifndef ARCTAN_LIM_SV
`define ARCTAN_LIM_SV

// arctan approximation (max 0.22deg deviation in range z=[0,1]) (in: FP; out: FP)
// using https://math.stackexchange.com/questions/1098487/atan2-faster-approximation
function automatic int arctan_lim(byte unsigned z);
	case (z)
		0: arctan_lim = 0;
		1: arctan_lim = 57;
		2: arctan_lim = 115;
		3: arctan_lim = 172;
		4: arctan_lim = 229;
		5: arctan_lim = 286;
		6: arctan_lim = 344;
		7: arctan_lim = 401;
		8: arctan_lim = 458;
		9: arctan_lim = 515;
		10: arctan_lim = 573;
		11: arctan_lim = 630;
		12: arctan_lim = 687;
		13: arctan_lim = 744;
		14: arctan_lim = 801;
		15: arctan_lim = 858;
		16: arctan_lim = 916;
		17: arctan_lim = 973;
		18: arctan_lim = 1030;
		19: arctan_lim = 1087;
		20: arctan_lim = 1144;
		21: arctan_lim = 1201;
		22: arctan_lim = 1257;
		23: arctan_lim = 1314;
		24: arctan_lim = 1371;
		25: arctan_lim = 1428;
		26: arctan_lim = 1485;
		27: arctan_lim = 1541;
		28: arctan_lim = 1598;
		29: arctan_lim = 1655;
		30: arctan_lim = 1711;
		31: arctan_lim = 1768;
		32: arctan_lim = 1824;
		33: arctan_lim = 1880;
		34: arctan_lim = 1937;
		35: arctan_lim = 1993;
		36: arctan_lim = 2049;
		37: arctan_lim = 2105;
		38: arctan_lim = 2161;
		39: arctan_lim = 2217;
		40: arctan_lim = 2273;
		41: arctan_lim = 2329;
		42: arctan_lim = 2385;
		43: arctan_lim = 2441;
		44: arctan_lim = 2497;
		45: arctan_lim = 2552;
		46: arctan_lim = 2608;
		47: arctan_lim = 2663;
		48: arctan_lim = 2719;
		49: arctan_lim = 2774;
		50: arctan_lim = 2829;
		51: arctan_lim = 2884;
		52: arctan_lim = 2939;
		53: arctan_lim = 2994;
		54: arctan_lim = 3049;
		55: arctan_lim = 3104;
		56: arctan_lim = 3159;
		57: arctan_lim = 3213;
		58: arctan_lim = 3268;
		59: arctan_lim = 3322;
		60: arctan_lim = 3377;
		61: arctan_lim = 3431;
		62: arctan_lim = 3485;
		63: arctan_lim = 3539;
		64: arctan_lim = 3593;
		65: arctan_lim = 3647;
		66: arctan_lim = 3701;
		67: arctan_lim = 3755;
		68: arctan_lim = 3808;
		69: arctan_lim = 3862;
		70: arctan_lim = 3915;
		71: arctan_lim = 3968;
		72: arctan_lim = 4021;
		73: arctan_lim = 4074;
		74: arctan_lim = 4127;
		75: arctan_lim = 4180;
		76: arctan_lim = 4233;
		77: arctan_lim = 4286;
		78: arctan_lim = 4338;
		79: arctan_lim = 4390;
		80: arctan_lim = 4443;
		81: arctan_lim = 4495;
		82: arctan_lim = 4547;
		83: arctan_lim = 4599;
		84: arctan_lim = 4650;
		85: arctan_lim = 4702;
		86: arctan_lim = 4754;
		87: arctan_lim = 4805;
		88: arctan_lim = 4856;
		89: arctan_lim = 4908;
		90: arctan_lim = 4959;
		91: arctan_lim = 5010;
		92: arctan_lim = 5060;
		93: arctan_lim = 5111;
		94: arctan_lim = 5162;
		95: arctan_lim = 5212;
		96: arctan_lim = 5262;
		97: arctan_lim = 5313;
		98: arctan_lim = 5363;
		99: arctan_lim = 5412;
		100: arctan_lim = 5462;
		101: arctan_lim = 5512;
		102: arctan_lim = 5561;
		103: arctan_lim = 5611;
		104: arctan_lim = 5660;
		105: arctan_lim = 5709;
		106: arctan_lim = 5758;
		107: arctan_lim = 5807;
		108: arctan_lim = 5856;
		109: arctan_lim = 5904;
		110: arctan_lim = 5953;
		111: arctan_lim = 6001;
		112: arctan_lim = 6049;
		113: arctan_lim = 6097;
		114: arctan_lim = 6145;
		115: arctan_lim = 6193;
		116: arctan_lim = 6240;
		117: arctan_lim = 6288;
		118: arctan_lim = 6335;
		119: arctan_lim = 6382;
		120: arctan_lim = 6429;
		121: arctan_lim = 6476;
		122: arctan_lim = 6523;
		123: arctan_lim = 6570;
		124: arctan_lim = 6616;
		125: arctan_lim = 6662;
		126: arctan_lim = 6709;
		127: arctan_lim = 6755;
		128: arctan_lim = 6801;
		129: arctan_lim = 6846;
		130: arctan_lim = 6892;
		131: arctan_lim = 6938;
		132: arctan_lim = 6983;
		133: arctan_lim = 7028;
		134: arctan_lim = 7073;
		135: arctan_lim = 7118;
		136: arctan_lim = 7163;
		137: arctan_lim = 7207;
		138: arctan_lim = 7252;
		139: arctan_lim = 7296;
		140: arctan_lim = 7340;
		141: arctan_lim = 7384;
		142: arctan_lim = 7428;
		143: arctan_lim = 7472;
		144: arctan_lim = 7516;
		145: arctan_lim = 7559;
		146: arctan_lim = 7602;
		147: arctan_lim = 7646;
		148: arctan_lim = 7689;
		149: arctan_lim = 7731;
		150: arctan_lim = 7774;
		151: arctan_lim = 7817;
		152: arctan_lim = 7859;
		153: arctan_lim = 7901;
		154: arctan_lim = 7944;
		155: arctan_lim = 7986;
		156: arctan_lim = 8027;
		157: arctan_lim = 8069;
		158: arctan_lim = 8111;
		159: arctan_lim = 8152;
		160: arctan_lim = 8193;
		161: arctan_lim = 8235;
		162: arctan_lim = 8275;
		163: arctan_lim = 8316;
		164: arctan_lim = 8357;
		165: arctan_lim = 8398;
		166: arctan_lim = 8438;
		167: arctan_lim = 8478;
		168: arctan_lim = 8518;
		169: arctan_lim = 8558;
		170: arctan_lim = 8598;
		171: arctan_lim = 8638;
		172: arctan_lim = 8677;
		173: arctan_lim = 8717;
		174: arctan_lim = 8756;
		175: arctan_lim = 8795;
		176: arctan_lim = 8834;
		177: arctan_lim = 8873;
		178: arctan_lim = 8912;
		179: arctan_lim = 8950;
		180: arctan_lim = 8989;
		181: arctan_lim = 9027;
		182: arctan_lim = 9065;
		183: arctan_lim = 9103;
		184: arctan_lim = 9141;
		185: arctan_lim = 9179;
		186: arctan_lim = 9216;
		187: arctan_lim = 9254;
		188: arctan_lim = 9291;
		189: arctan_lim = 9328;
		190: arctan_lim = 9365;
		191: arctan_lim = 9402;
		192: arctan_lim = 9439;
		193: arctan_lim = 9475;
		194: arctan_lim = 9512;
		195: arctan_lim = 9548;
		196: arctan_lim = 9584;
		197: arctan_lim = 9620;
		198: arctan_lim = 9656;
		199: arctan_lim = 9692;
		200: arctan_lim = 9728;
		201: arctan_lim = 9763;
		202: arctan_lim = 9799;
		203: arctan_lim = 9834;
		204: arctan_lim = 9869;
		205: arctan_lim = 9904;
		206: arctan_lim = 9939;
		207: arctan_lim = 9973;
		208: arctan_lim = 10008;
		209: arctan_lim = 10042;
		210: arctan_lim = 10077;
		211: arctan_lim = 10111;
		212: arctan_lim = 10145;
		213: arctan_lim = 10179;
		214: arctan_lim = 10213;
		215: arctan_lim = 10246;
		216: arctan_lim = 10280;
		217: arctan_lim = 10313;
		218: arctan_lim = 10347;
		219: arctan_lim = 10380;
		220: arctan_lim = 10413;
		221: arctan_lim = 10446;
		222: arctan_lim = 10478;
		223: arctan_lim = 10511;
		224: arctan_lim = 10544;
		225: arctan_lim = 10576;
		226: arctan_lim = 10608;
		227: arctan_lim = 10640;
		228: arctan_lim = 10672;
		229: arctan_lim = 10704;
		230: arctan_lim = 10736;
		231: arctan_lim = 10768;
		232: arctan_lim = 10799;
		233: arctan_lim = 10831;
		234: arctan_lim = 10862;
		235: arctan_lim = 10893;
		236: arctan_lim = 10924;
		237: arctan_lim = 10955;
		238: arctan_lim = 10986;
		239: arctan_lim = 11016;
		240: arctan_lim = 11047;
		241: arctan_lim = 11077;
		242: arctan_lim = 11108;
		243: arctan_lim = 11138;
		244: arctan_lim = 11168;
		245: arctan_lim = 11198;
		246: arctan_lim = 11228;
		247: arctan_lim = 11258;
		248: arctan_lim = 11287;
		249: arctan_lim = 11317;
		250: arctan_lim = 11346;
		251: arctan_lim = 11375;
		252: arctan_lim = 11405;
		253: arctan_lim = 11434;
		254: arctan_lim = 11462;
		255: arctan_lim = 11491;
	endcase
endfunction

`endif