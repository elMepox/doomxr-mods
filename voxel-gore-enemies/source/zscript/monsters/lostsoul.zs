// Lost Soul: a burning skull (VGL_ORB). The face (brow and sockets) is the weak spot (x2), the cheekbones
// are the side zones, the jaw is the mouth zone. Hits throw bone chips, the face spits embers.
// It has no meat to bleed: death shatters the skull (death_explode chunks) in a burst of fire and bone,
// the pieces drop while it falls, then it is gone like in vanilla (no corpse for the Pain Elemental to count).
class VoxelLostSoul : LostSoul replaces LostSoul
{
	mixin VoxelGore;
	Default { +DECOUPLEDANIMATIONS }
	override void BeginPlay()
	{
		Super.BeginPlay();
		VG_Setup("models/lostsoul", "ls", 0);
		VG_Layout(VGL_ORB, 1);
		VG_Zone(0, "face",    VGS_FIRE, 2, 'None', 'pain_face');
		VG_Zone(1, "skull",   VGS_BONE, 1, 'None', 'pain_skull');
		VG_Zone(2, "cheek_l", VGS_BONE, 1, 'None', 'pain_cheek_l');
		VG_Zone(3, "cheek_r", VGS_BONE, 1, 'None', 'pain_cheek_r');
		VG_Zone(4, "jaw",     VGS_BONE, 1, 'None', 'pain_jaw');
		vgBurstSpray = VGS_BONE;
	}

	// fire licking off the skull, more of it while it charges
	void LS_Fire(int n)
	{
		TextureID none = TexMan.CheckForTexture("");
		Vector2 back = AngleToVector(Angle, -Radius * 0.4);
		for (int i = 0; i < n; i++)
			A_SpawnParticleEx(Color(255, 255, random(80, 200), random(0, 40)), none, STYLE_Add, SPF_FULLBRIGHT, random(8, 18),
				frandom(2, 5), -0.2, back.x + frandom(-6, 6), back.y + frandom(-6, 6), Height * frandom(0.55, 0.8),
				frandom(-0.3, 0.3), frandom(-0.3, 0.3), frandom(0.8, 2.2), 0, 0, 0.05);
	}

	void LS_Death()
	{
		// the zone that took the killing hit cracks open before the skull flies apart
		if (lastZone >= 0 && !zoneBroken[lastZone])
		{
			zoneBroken[lastZone] = true;
			A_ChangeModel("", lastZone, vgPath, VG_ZoneModel(lastZone, 1));
		}
		VG_Burst();
		VG_Spray(VGS_FIRE, Pos + (0, 0, Height * 0.6), Angle, 90);
		// drops while the pieces fly (vanilla keeps it hanging in the air and just vanishes)
		bNoGravity = false; bFloat = false;
	}

	States
	{
	Spawn:
		SKUL A 0 NoDelay A_SetAnimation('idle', flags: SAF_LOOP | SAF_NOOVERRIDE);
		SKUL AB 10 Bright { A_Look(); LS_Fire(3); }
		Goto Spawn+1;
	See:
		SKUL A 0 A_SetAnimation('fly', flags: SAF_LOOP | SAF_NOOVERRIDE);
		SKUL AB 6 Bright { A_Chase(); LS_Fire(4); }
		Goto See+1;
	Missile:
		SKUL C 0 Bright { SetAnimation('attack', interpolateTics: 2); }
		SKUL C 10 Bright { A_FaceTarget(); LS_Fire(6); }
		SKUL D 0 Bright A_SetAnimation('charge', interpolateTics: 2, flags: SAF_LOOP);
		SKUL D 4 Bright { A_SkullAttack(); LS_Fire(10); }
		SKUL CD 4 Bright LS_Fire(10);
		Goto Missile+4;
	Pain:
		SKUL E 0 Bright { SetAnimation(VG_PainAnim(), interpolateTics: 2); }
		SKUL E 3 Bright;
		SKUL E 3 Bright A_Pain;
		Goto See;
	Death:
		SKUL F 0 Bright LS_Death;
		SKUL F 6 Bright;
		SKUL G 6 Bright A_Scream;
		SKUL H 6 Bright;
		SKUL I 6 Bright A_NoBlocking;
		SKUL J 6;
		SKUL K 6;
		SKUL K 12;
		Stop;
	}
}
