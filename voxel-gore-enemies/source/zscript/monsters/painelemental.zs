// Pain Elemental: a floating ball (VGL_ORB) with two stunted arms. The eye is the weak spot (x2), each side
// is its arm zone, the jaw is the mouth zone. Red blood like vanilla. Spits Lost Souls (A_PainAttack spawns
// LostSoul, so our VoxelLostSoul replacement comes out). Every death: the killing hit, the ball bloats and
// shakes in the air (death_swell), then it bursts (death_explode, Cell Fracture shards), the souls fly out
// of the tear (A_PainDie) and the remains drop to the floor.
class VoxelPainElemental : PainElemental replaces PainElemental
{
	mixin VoxelGore;
	Default { +DECOUPLEDANIMATIONS GibHealth -150; }
	override void BeginPlay()
	{
		Super.BeginPlay();
		VG_Setup("models/painelemental", "pe", 0);
		VG_Layout(VGL_ORB, 1);
		VG_Zone(0, "face",  VGS_BLOOD, 2, 'death_face', 'pain_face');
		VG_Zone(1, "body",  VGS_BLOOD, 1, 'death_hit',  'pain_body');
		VG_Zone(2, "arm_l", VGS_BLOOD, 1, 'death_hit',  'pain_arm_l');
		VG_Zone(3, "arm_r", VGS_BLOOD, 1, 'death_hit',  'pain_arm_r');
		VG_Zone(4, "mouth", VGS_BLOOD, 1, 'death_hit',  'pain_mouth');
	}

	// the furnace in the throat flares up while a soul is being retched out
	void PE_MawGlow(int n)
	{
		Vector2 f = AngleToVector(Angle, Radius * 0.8);
		for (int i = 0; i < n; i++)
			A_SpawnParticleEx(Color(255, 255, random(90, 160), random(10, 40)), TexMan.CheckForTexture(""), STYLE_Add,
				SPF_FULLBRIGHT, random(5, 10), frandom(2, 4.5), 0, f.x + frandom(-5, 5), f.y + frandom(-5, 5), Height * 0.45 + frandom(-3, 3),
				frandom(-0.3, 0.3), frandom(-0.3, 0.3), frandom(0, 0.6));
	}

	void PE_Death()
	{
		Name d = VG_DeathAnim();
		if (d == 'death_blast') d = 'death_hit';   // no thrown-back death: it always bursts
		if (d == 'death_face' && !zoneBroken[0])
		{
			// the eye bursts on a killing shot even if the zone was not wounded yet
			zoneBroken[0] = true;
			A_ChangeModel("", 0, vgPath, VG_ZoneModel(0, 1));
			VG_Spray(VGS_BLOOD, Pos + (AngleToVector(Angle, Radius * 0.8), Height * 0.6), Angle, 70);
		}
		SetAnimation(d, interpolateTics: 2);
	}

	void PE_Burst()
	{
		VG_Burst();            // death_explode + blood + meat chunks
		bNoGravity = false;    // the remains drop to the floor while the shards scatter
	}

	States
	{
	Spawn:
		PAIN A 0 NoDelay A_SetAnimation('idle', flags: SAF_LOOP | SAF_NOOVERRIDE);
		PAIN A 10 A_Look;
		Wait;
	See:
		PAIN A 0 A_SetAnimation('fly', flags: SAF_LOOP | SAF_NOOVERRIDE);
		PAIN A 3 A_Chase;
		Loop;
	Missile:
		PAIN D 0 SetAnimation('attack', interpolateTics: 2);
		PAIN D 5 A_FaceTarget;
		PAIN E 5 { A_FaceTarget(); PE_MawGlow(14); }
		PAIN F 5 Bright { A_FaceTarget(); PE_MawGlow(10); }
		PAIN F 0 Bright A_PainAttack;
		Goto See;
	Pain:
		PAIN G 0 { SetAnimation(VG_PainAnim(), interpolateTics: 2); }
		PAIN G 6;
		PAIN G 6 A_Pain;
		Goto See;
	Death:
		PAIN H 0 PE_Death;
		PAIN H 8 Bright;
		PAIN H 0 SetAnimation('death_swell', interpolateTics: 2);
		PAIN I 8 Bright A_Scream;
		PAIN JK 8 Bright;
		PAIN L 0 Bright PE_Burst;
		PAIN L 8 Bright A_PainDie;
		PAIN M 8 Bright;
		PAIN M 24 A_NoBlocking;
		PAIN M -1;
		Stop;
	XDeath:
		// overkill: no swelling, it bursts at once
		PAIN H 0 PE_Burst;
		PAIN H 8 Bright A_PainDie;
		PAIN I 8 Bright A_XScream;
		PAIN JKLM 8 Bright;
		PAIN M 24 A_NoBlocking;
		PAIN M -1;
		Stop;
	Raise:
		PAIN M 0 { VG_Heal(); bNoGravity = true; }
		PAIN M 8;
		PAIN LKJIH 8;
		Goto See;
	}
}
