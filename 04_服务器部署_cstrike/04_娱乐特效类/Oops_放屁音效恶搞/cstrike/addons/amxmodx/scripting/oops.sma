#include <amxmodx>
#include <reapi>

enum Cvars {
	FART_CHANCE,
	Float:DUCK_BREAK,
	STENCH
}

new g_iSmokeSpriteID

new g_eCvar[Cvars]

new const g_szFartingSounds[][] = {
	"oops/oops1.wav",
	"oops/oops2.wav",
	"oops/oops3.wav",
	"oops/oops4.wav",
	"oops/oops5.wav"
}

public plugin_precache() {
	for(new i; i < sizeof(g_szFartingSounds); i++) {
		precache_sound(g_szFartingSounds[i])
	}
	
	g_iSmokeSpriteID = precache_model("sprites/smoke.spr")
}

public plugin_init() {
	register_plugin("Oops!", "1.1", "CHEL74")
	
	RegisterHookChain(RG_CBasePlayer_Duck, "Duck_Post", true)
	
	RegisterCvars()
}

public Duck_Post(pPlayer) {
	new Float:fCurrentTime = get_gametime()
	
	// Чтобы при дабл даке и передвижении вприсяди это не было постоянно :D
	static Float:fLastFartTime[MAX_PLAYERS + 1]
	
	if(fCurrentTime - fLastFartTime[pPlayer] < 0.15) {
		fLastFartTime[pPlayer] = fCurrentTime
		
		return
	}
	
	fLastFartTime[pPlayer] = fCurrentTime
	
	static Float:fNextFartTime[MAX_PLAYERS + 1]
	
	if(fNextFartTime[pPlayer] > fCurrentTime) {
		return
	}
	
	if(random_num(1, 10000) > g_eCvar[FART_CHANCE] * 100) {
		return
	}
	
	emit_sound(pPlayer, CHAN_AUTO, g_szFartingSounds[random(sizeof(g_szFartingSounds))], 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	if(g_eCvar[STENCH]) {
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BEAMFOLLOW)
		write_short(pPlayer)
		write_short(g_iSmokeSpriteID)
		write_byte(30)	// Life
		write_byte(40)	// Line width
		write_byte(0)	// Red
		write_byte(255)	// Green
		write_byte(0)	// Blue
		write_byte(60)	// Brightness
		message_end()
	}
	
	fNextFartTime[pPlayer] = fCurrentTime + g_eCvar[DUCK_BREAK]
}

RegisterCvars() {
	bind_pcvar_num(
		create_cvar(
			"oops_fart_chance", "5", FCVAR_SERVER,
			.description = "Шанс пука при приседании в процентах",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 100.0
		),
		g_eCvar[FART_CHANCE]
	)
	
	bind_pcvar_float(
		create_cvar(
			"oops_duck_break", "20", FCVAR_SERVER,
			.description = "Через сколько секунд возможен повторный пук",
			.has_min = true, .min_val = 0.1
		),
		g_eCvar[DUCK_BREAK]
	)
	
	bind_pcvar_num(
		create_cvar(
			"oops_stench", "1", FCVAR_SERVER,
			.description = "Шлейф от пукнувшего игрока",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 1.0
		),
		g_eCvar[STENCH]
	)
	
	AutoExecConfig(true, "config", "Oops")
}