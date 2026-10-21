// Cyberdemon: a 3.6 m boss on the Baron's skeleton. Right forearm = rocket launcher (sparks and metal chips
// when hit), left leg = steel prosthesis. Boss rules from the mixin: wounds at min(15% health, 150) damage,
// no headshot bonus. Every kill plays death_boss: the launcher arm, the chest and the head blow off one after
// another (explosions on the same tics), the legs stand on and topple last; the remains lie like the vanilla corpse.
// Model: built with Blender's own tools (Remesh Blocks voxels, Cycles-baked lit texture), not vg_shade.
// cy_tex.png is a 2:1 atlas: left half = intact (_0 models), right half = wounded (_1), so A_ChangeModel needs no skin swap.
class VoxelCyberdemon : Cyberdemon replaces Cyberdemon
{
	mixin VoxelGore;
	Default { +DECOUPLEDANIMATIONS }
	override void BeginPlay()
	{
		Super.BeginPlay();
		VG_Setup("models/cyberdemon", "cy", 19);
		vgHeadZ = 0.84; vgLegsZ = 0.45;
		VG_Zone(Z_ARM_R, "arm_r", VGS_METAL, 1, 'None', 'pain_arm_r');
	}

	// one blast of the death chain at a height (fraction of Height) on a side (+ = its left)
	void CY_Boom(double z, double side, int spray)
	{
		Vector2 s = AngleToVector(Angle + 90, side * Radius);
		Vector3 at = Pos + (s.x, s.y, Height * z);
		Spawn("VGCyberBoom", at, ALLOW_REPLACE);
		VG_Spray(spray, at, frandom(0, 360), 90);
		VG_Spray(VGS_FIRE, at, frandom(0, 360), 50);
	}

	States
	{
	Spawn:
		CYBR A 0 NoDelay A_SetAnimation('idle', flags: SAF_LOOP | SAF_NOOVERRIDE);
		CYBR AB 10 A_Look;
		Loop;
	See:
		// walk: 24 tics; the hoof stamps on tic 0, the steel leg on tic 12 (vanilla: 18), same 8 chase calls
		CYBR A 0 A_SetAnimation('walk', flags: SAF_LOOP | SAF_NOOVERRIDE);
		CYBR A 3 A_Hoof;
		CYBR ABB 3 A_Chase;
		CYBR C 3 A_Metal;
		CYBR CDD 3 A_Chase;
		Loop;
	Missile:
		// attack: 6 tics aim, rockets on tics 7, 31, 55, 78 tics in all
		CYBR E 0 SetAnimation('attack');
		CYBR E 6 A_FaceTarget;
		CYBR F 12 A_CyberAttack;
		CYBR E 12 A_FaceTarget;
		CYBR F 12 A_CyberAttack;
		CYBR E 12 A_FaceTarget;
		CYBR F 12 A_CyberAttack;
		Goto See;
	Pain:
		CYBR G 0 { SetAnimation(VG_PainAnim(), interpolateTics: 2); }
		CYBR G 10 A_Pain;
		Goto See;
	Death:
		// death_boss (Rigid Body chunks baked in Blender): launcher arm off on tic 12, head on 30, chest on 50,
		// the legs stand until 79 and topple backwards, still from ~125
		CYBR H 0 { SetAnimation('death_boss', interpolateTics: 2); }
		CYBR H 10;
		CYBR I 2 A_Scream;
		CYBR I 8 CY_Boom(0.6, -0.8, VGS_METAL);
		CYBR J 10;
		CYBR K 10 CY_Boom(0.9, 0, VGS_BLOOD);
		CYBR L 10;
		CYBR M 10 CY_Boom(0.65, 0, VGS_BLOOD);
		CYBR N 10 A_NoBlocking;
		CYBR O 10;
		CYBR P 30;
		CYBR P -1 A_BossDeath;
		Stop;
	}
}

// fireball of the boss death chain: the rocket explosion frames, bigger and with the rocket's bang
class VGCyberBoom : Actor
{
	Default { +NOINTERACTION RenderStyle "Add"; Scale 1.6; }
	States
	{
	Spawn:
		MISL B 0 Bright NoDelay A_StartSound("weapons/rocklx", CHAN_AUTO, attenuation: 0.5);
		MISL B 8 Bright;
		MISL C 6 Bright;
		MISL D 4 Bright;
		Stop;
	}
}
