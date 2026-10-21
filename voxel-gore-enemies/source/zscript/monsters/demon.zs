// Demon (Pinky) and Spectre: one hunched beast body, only a bite. The head hangs low in front of the chest,
// so the head zone starts lower than on the humanoids.
class VoxelDemon : Demon replaces Demon
{
	mixin VoxelGore;
	Default { +DECOUPLEDANIMATIONS GibHealth -75; }  // vanilla has no XDeath here; gib on a hard overkill
	override void BeginPlay()
	{
		Super.BeginPlay();
		VG_Setup("models/pinky", "dm", 9);
		vgHeadZ = 0.5; vgLegsZ = 0.3;   // the model (1.33 m) is shorter than the 56-unit hitbox: big low head, short legs
	}
	States
	{
	Spawn:
		SARG A 0 NoDelay A_SetAnimation('idle', flags: SAF_LOOP | SAF_NOOVERRIDE);
		SARG A 10 A_Look;
		Wait;
	See:
		SARG A 0 A_SetAnimation('walk', framerate: 60, flags: SAF_LOOP | SAF_NOOVERRIDE);
		SARG AABBCCDD 2 A_Chase;
		Loop;
	Melee:
		SARG E 0 SetAnimation('melee');
		SARG EF 8 A_FaceTarget;
		SARG G 8 A_SargAttack;
		Goto See;
	Pain:
		SARG H 0 { SetAnimation(VG_PainAnim(), interpolateTics: 2); }
		SARG H 2;
		SARG H 2 A_Pain;
		SARG H 8;
		Goto See;
	Death:
		SARG I 0 { SetAnimation(VG_DeathAnim(), interpolateTics: 2); }
		SARG I 8;
		SARG J 8 A_Scream;
		SARG K 4;
		SARG L 4 A_NoBlocking;
		SARG M 4;
		SARG N -1;
		Stop;
	XDeath:
		SARG I 0 VG_Burst;
		SARG I 8;
		SARG J 8 A_XScream;
		SARG K 4;
		SARG L 4 A_NoBlocking;
		SARG M 4;
		SARG N -1;
		Stop;
	Raise:
		SARG N 0 VG_Heal;
		SARG N 5;
		SARG MLKJI 5;
		Goto See;
	}
}

// Spectre: the same model, drawn with the vanilla partial invisibility (RenderStyle OptFuzzy from Spectre).
class VoxelSpectre : VoxelDemon replaces Spectre
{
	Default
	{
		+SHADOW
		RenderStyle "OptFuzzy";
		Alpha 0.5;
		SeeSound "spectre/sight";
		AttackSound "spectre/melee";
		PainSound "spectre/pain";
		DeathSound "spectre/death";
		ActiveSound "spectre/active";
		HitObituary "$OB_SPECTREHIT";
		Tag "$FN_SPECTRE";
	}
}
