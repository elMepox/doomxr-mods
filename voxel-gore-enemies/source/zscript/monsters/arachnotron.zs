// Arachnotron: a brain on four mechanical legs (VGL_SPIDER). The brain is the weak spot (x2) and bleeds; the
// chassis, the legs and the gun throw sparks and metal chips. Deaths by zone: legs on one side buckle and it
// rolls onto that side, the brain bursts and the legs fold, anything else collapses it onto its belly;
// an explosion throws it onto its back with the legs curled; a hard overkill blows it apart.
class VoxelArachnotron : Arachnotron replaces Arachnotron
{
	mixin VoxelGore;
	Default { +DECOUPLEDANIMATIONS GibHealth -150; }  // vanilla has no XDeath; gib on a hard overkill
	override void BeginPlay()
	{
		Super.BeginPlay();
		VG_Setup("models/arachnotron", "ar", 0);
		VG_Layout(VGL_SPIDER, 1);
		vgBurstSpray = VGS_BLOOD;
		VG_Zone(0, "brain",   VGS_BLOOD, 2, 'death_brain',    'pain_brain');
		VG_Zone(1, "chassis", VGS_METAL, 1, 'death_collapse', 'pain_chassis');
		VG_Zone(2, "legs_l",  VGS_METAL, 1, 'death_legs_l',   'pain_legs_l');
		VG_Zone(3, "legs_r",  VGS_METAL, 1, 'death_legs_r',   'pain_legs_r');
		VG_Zone(4, "gun",     VGS_METAL, 1, 'death_collapse', 'pain_gun');
	}

	// green plasma gathering at the muzzles while it takes aim
	void AR_Charge(int n)
	{
		Vector2 f = AngleToVector(Angle, 46);
		Vector2 s = AngleToVector(Angle + 90, 3);
		for (int i = 0; i < n; i++)
		{
			double k = random(0, 1) ? 1 : -1;
			A_SpawnParticleEx(Color(255, random(60, 140), 255, random(110, 170)), TexMan.CheckForTexture(""), STYLE_Add,
				SPF_FULLBRIGHT, random(4, 8), frandom(1.5, 3), 0, f.x + s.x * k + frandom(-2, 2), f.y + s.y * k + frandom(-2, 2), 24 + frandom(-2, 2),
				frandom(-0.2, 0.2), frandom(-0.2, 0.2), frandom(-0.1, 0.2));
		}
	}

	// footfall: grit kicked up around the feet
	void AR_Step()
	{
		A_BabyMetal();
		for (int i = 0; i < 4; i++)
		{
			Vector2 p = AngleToVector(Angle + 45 + 90 * i, 52);
			int g = random(60, 90);
			A_SpawnParticleEx(Color(255, g, g - 6, g - 14), TexMan.CheckForTexture(""), STYLE_Normal, 0, random(12, 20), frandom(2, 3.5), 0,
				p.x, p.y, 1, frandom(-0.6, 0.6), frandom(-0.6, 0.6), frandom(0.4, 1.2), 0, 0, -0.15);
		}
	}

	void AR_Death()
	{
		Name d = VG_DeathAnim();
		if (d == 'death_brain' && !zoneBroken[0])
		{
			// the brain bursts on a killing shot even if the zone was not wounded yet
			zoneBroken[0] = true;
			A_ChangeModel("", 0, vgPath, VG_ZoneModel(0, 1));
		}
		if (d == 'death_brain')
			for (int i = 0; i < 3; i++)
				VG_Spray(VGS_BLOOD, Pos + (0, 0, Height * 0.75), frandom(0, 360), 50);
		SetAnimation(d, interpolateTics: 2);
	}

	States
	{
	Spawn:
		BSPI A 0 NoDelay A_SetAnimation('idle', flags: SAF_LOOP | SAF_NOOVERRIDE);
		BSPI AB 10 A_Look;
		Goto Spawn + 1;
	See:
		BSPI A 0 A_SetAnimation('idle', flags: SAF_LOOP | SAF_NOOVERRIDE);
		BSPI A 20;
	See2:
		BSPI A 0 A_SetAnimation('walk', flags: SAF_LOOP | SAF_NOOVERRIDE);
		BSPI A 3 AR_Step;
		BSPI ABBCC 3 A_Chase;
		BSPI D 3 AR_Step;
		BSPI DEEFF 3 A_Chase;
		Loop;
	Missile:
		BSPI A 0 A_SetAnimation('attack', interpolateTics: 3);
		BSPI A 10 BRIGHT { A_FaceTarget(); AR_Charge(10); }
		BSPI A 10 BRIGHT { A_FaceTarget(); AR_Charge(16); }
	Fire:
		BSPI G 0 A_SetAnimation('fire', interpolateTics: 1, flags: SAF_LOOP | SAF_NOOVERRIDE);
		BSPI G 4 BRIGHT A_BspiAttack;
		BSPI H 4 BRIGHT;
		BSPI H 1 BRIGHT A_SpidRefire;
		Loop;
	Pain:
		BSPI I 0 { SetAnimation(VG_PainAnim(), interpolateTics: 2); }
		BSPI I 3;
		BSPI I 3 A_Pain;
		Goto See2;
	Death:
		BSPI J 0 AR_Death;
		BSPI J 20 A_Scream;
		BSPI K 7 A_NoBlocking;
		BSPI LMNO 7;
		BSPI P -1 A_BossDeath;
		Stop;
	XDeath:
		BSPI J 0 VG_Burst;
		BSPI J 20 A_Scream;
		BSPI K 7 A_NoBlocking;
		BSPI LMNO 7;
		BSPI P -1 A_BossDeath;   // MAP07 and friends count dead arachnotrons: keep it on every death
		Stop;
	Raise:
		BSPI P 0 VG_Heal;
		BSPI P 5;
		BSPI ONMLKJ 5;
		Goto See2;
	}
}
