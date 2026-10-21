// Cacodemon: a floating ball (VGL_ORB). The eye is the weak spot (x2), each side has its horn zone,
// the jaw is the mouth zone. Bleeds blue. Dies in the air: the zone death, then a lurching tumble
// while it drops (it loses NOGRAVITY like in vanilla), then death_land splats it on the floor.
class VoxelCacodemon : Cacodemon replaces Cacodemon
{
	mixin VoxelGore;
	Default { +DECOUPLEDANIMATIONS BloodColor "20 38 D8"; GibHealth -120; }  // vanilla has no XDeath; gib on a hard overkill
	override void BeginPlay()
	{
		Super.BeginPlay();
		VG_Setup("models/cacodemon", "cc", 0);
		VG_Layout(VGL_ORB, 1);
		VG_Zone(0, "eye",    VGS_BLOOD, 2, 'death_eye', 'pain_eye');
		VG_Zone(1, "shell",  VGS_BLOOD, 1, 'death_air', 'pain_shell');
		VG_Zone(2, "horn_l", VGS_BLOOD, 1, 'death_air', 'pain_horn_l');
		VG_Zone(3, "horn_r", VGS_BLOOD, 1, 'death_air', 'pain_horn_r');
		VG_Zone(4, "mouth",  VGS_BLOOD, 1, 'death_air', 'pain_mouth');
	}

	// glowing spit gathering in the open maw before A_HeadAttack
	void CC_MawGlow(int n)
	{
		Vector2 f = AngleToVector(Angle, Radius * 0.75);
		for (int i = 0; i < n; i++)
			A_SpawnParticleEx(Color(255, random(200, 255), random(40, 90), random(140, 220)), TexMan.CheckForTexture(""), STYLE_Add,
				SPF_FULLBRIGHT, random(4, 9), frandom(2, 4), 0, f.x + frandom(-4, 4), f.y + frandom(-4, 4), Height * 0.4 + frandom(-3, 3),
				frandom(-0.3, 0.3), frandom(-0.3, 0.3), frandom(-0.2, 0.4));
	}

	void CC_Death()
	{
		Name d = VG_DeathAnim();
		if (d == 'death_eye' && !zoneBroken[0])
		{
			// the eye bursts on a killing shot even if the zone was not wounded yet
			zoneBroken[0] = true;
			A_ChangeModel("", 0, vgPath, VG_ZoneModel(0, 1));
			VG_Spray(VGS_BLOOD, Pos + (AngleToVector(Angle, Radius * 0.8), Height * 0.6), Angle, 70);
		}
		SetAnimation(d, interpolateTics: 2);
	}

	States
	{
	Spawn:
		HEAD A 0 NoDelay A_SetAnimation('idle', flags: SAF_LOOP | SAF_NOOVERRIDE);
		HEAD A 10 A_Look;
		Wait;
	See:
		HEAD A 0 A_SetAnimation('fly', flags: SAF_LOOP | SAF_NOOVERRIDE);
		HEAD A 3 A_Chase;
		Loop;
	Missile:
		HEAD B 0 { SetAnimation(CheckMeleeRange() ? 'melee' : 'attack', interpolateTics: 2); }
		HEAD B 5 A_FaceTarget;
		HEAD C 5 { A_FaceTarget(); CC_MawGlow(12); }
		HEAD D 5 Bright A_HeadAttack;
		Goto See;
	Pain:
		HEAD E 0 { SetAnimation(VG_PainAnim(), interpolateTics: 2); }
		HEAD E 3;
		HEAD E 3 A_Pain;
		HEAD F 6;
		Goto See;
	Death:
		HEAD G 0 CC_Death;
		HEAD G 8;
		HEAD H 4 A_Scream;
		// still in the air: tumble while it drops (lands within a tic: straight to the splat)
		HEAD I 0 { if (Pos.z > FloorZ + 1 && !bOnMobj) SetAnimation('death_fall', interpolateTics: 4, flags: SAF_LOOP); }
		HEAD I 1 { return VG_AirFall("DeathLand"); }
		Wait;
	DeathLand:
		HEAD J 8;
		HEAD K 8 A_NoBlocking;
		HEAD L -1;
		Stop;
	XDeath:
		// torn apart in the air: the chunks rain down with the remains
		HEAD G 0 VG_Burst;
		HEAD G 8 A_XScream;
		HEAD H 8;
		HEAD I 8 A_NoBlocking;
		HEAD JK 8;
		HEAD L -1;
		Stop;
	Raise:
		HEAD L 0 VG_Heal;
		HEAD L 8;
		HEAD KJIHG 8;
		Goto See;
	}
}
