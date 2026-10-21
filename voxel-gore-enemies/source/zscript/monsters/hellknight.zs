// Hell Knight
class VoxelHellKnight : HellKnight replaces HellKnight
{
	mixin VoxelGore;
	Default { +DECOUPLEDANIMATIONS GibHealth -150; }  // vanilla has no XDeath here; gib on a hard overkill
	override void BeginPlay() { Super.BeginPlay(); VG_Setup("models/hellknight", "hk", 10); }
	States
	{
	Spawn:
		BOS2 A 0 NoDelay A_SetAnimation('idle', flags: SAF_LOOP | SAF_NOOVERRIDE);
		BOS2 A 10 A_Look;
		Wait;
	See:
		BOS2 A 0 A_SetAnimation('walk', framerate: 46, flags: SAF_LOOP | SAF_NOOVERRIDE);
		BOS2 AABBCCDD 3 A_Chase;
		Loop;
	Melee:
	Missile:
		BOS2 E 0 { SetAnimation(CheckMeleeRange() ? 'melee' : 'attack', framerate: CheckMeleeRange() ? 26 : 35); }
		BOS2 EF 8 A_FaceTarget;
		BOS2 G 8 A_BruisAttack;
		Goto See;
	Pain:
		BOS2 H 0 { SetAnimation(VG_PainAnim(), interpolateTics: 2); }
		BOS2 H 2;
		BOS2 H 2 A_Pain;
		BOS2 H 6;
		Goto See;
	Death:
		BOS2 I 0 { SetAnimation(VG_DeathAnim(), interpolateTics: 2); }
		BOS2 I 8;
		BOS2 J 8 A_Scream;
		BOS2 K 8;
		BOS2 L 8 A_NoBlocking;
		BOS2 MN 8;
		BOS2 O -1;
		Stop;
	XDeath:
		BOS2 I 0 VG_Burst;
		BOS2 I 8;
		BOS2 J 8 A_XScream;
		BOS2 K 8;
		BOS2 L 8 A_NoBlocking;
		BOS2 MN 8;
		BOS2 O -1;
		Stop;
	Raise:
		BOS2 O 0 VG_Heal;
		BOS2 O 8;
		BOS2 NMLKJI 8;
		Goto See;
	}
}
