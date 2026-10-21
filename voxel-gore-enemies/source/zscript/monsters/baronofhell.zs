// Baron of Hell
class VoxelBaronOfHell : BaronOfHell replaces BaronOfHell
{
	mixin VoxelGore;
	Default { +DECOUPLEDANIMATIONS GibHealth -300; }  // vanilla has no XDeath here; gib on a hard overkill
	override void BeginPlay() { Super.BeginPlay(); VG_Setup("models/baron", "bh", 11); }
	States
	{
	Spawn:
		BOSS A 0 NoDelay A_SetAnimation('idle', flags: SAF_LOOP | SAF_NOOVERRIDE);
		BOSS A 10 A_Look;
		Wait;
	See:
		BOSS A 0 A_SetAnimation('walk', framerate: 46, flags: SAF_LOOP | SAF_NOOVERRIDE);
		BOSS AABBCCDD 3 A_Chase;
		Loop;
	Melee:
	Missile:
		BOSS E 0 { SetAnimation(CheckMeleeRange() ? 'melee' : 'attack', framerate: CheckMeleeRange() ? 26 : 35); }
		BOSS EF 8 A_FaceTarget;
		BOSS G 8 A_BruisAttack;
		Goto See;
	Pain:
		BOSS H 0 { SetAnimation(VG_PainAnim(), interpolateTics: 2); }
		BOSS H 2;
		BOSS H 2 A_Pain;
		BOSS H 6;
		Goto See;
	Death:
		BOSS I 0 { SetAnimation(VG_DeathAnim(), interpolateTics: 2); }
		BOSS I 8;
		BOSS J 8 A_Scream;
		BOSS K 8;
		BOSS L 8 A_NoBlocking;
		BOSS MN 8;
		BOSS O -1 A_BossDeath;
		Stop;
	XDeath:
		BOSS I 0 VG_Burst;
		BOSS I 8;
		BOSS J 8 A_XScream;
		BOSS K 8;
		BOSS L 8 A_NoBlocking;
		BOSS MN 8;
		BOSS O -1 A_BossDeath;
		Stop;
	Raise:
		BOSS O 0 VG_Heal;
		BOSS O 8;
		BOSS NMLKJI 8;
		Goto See;
	}
}
