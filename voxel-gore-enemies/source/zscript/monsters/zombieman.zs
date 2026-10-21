// Zombieman
class VoxelZombieman : ZombieMan replaces ZombieMan
{
	mixin VoxelGore;
	Default { +DECOUPLEDANIMATIONS }
	override void BeginPlay() { Super.BeginPlay(); VG_Setup("models/zombieman", "zm", 7); }
	States
	{
	Spawn:
		POSS A 0 NoDelay A_SetAnimation('idle', flags: SAF_LOOP | SAF_NOOVERRIDE);
		POSS A 10 A_Look;
		Wait;
	See:
		POSS A 0 A_SetAnimation('walk', flags: SAF_LOOP | SAF_NOOVERRIDE);
		POSS AABBCCDD 4 A_Chase;
		Loop;
	Missile:
		POSS E 0 A_SetAnimation('attack');
		POSS E 10 A_FaceTarget;
		POSS F 8 A_PosAttack;
		POSS E 12;
		Goto See;
	Pain:
		POSS G 0 { SetAnimation(VG_PainAnim(), interpolateTics: 2); }
		POSS G 3;
		POSS G 3 A_Pain;
		POSS G 6;
		Goto See;
	Death:
		POSS H 0 { SetAnimation(VG_DeathAnim(), interpolateTics: 2); }
		POSS H 5;
		POSS I 5 A_Scream;
		POSS J 5 A_NoBlocking;
		POSS K 20;
		POSS L -1;
		Stop;
	XDeath:
		POSS M 0 VG_Burst;
		POSS M 5;
		POSS N 5 A_XScream;
		POSS O 5 A_NoBlocking;
		POSS PQRST 5;
		POSS U -1;
		Stop;
	Raise:
		POSS K 0 VG_Heal;
		POSS K 5;
		POSS JIH 5;
		Goto See;
	}
}
