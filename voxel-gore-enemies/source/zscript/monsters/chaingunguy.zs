// Chaingunner
class VoxelChaingunGuy : ChaingunGuy replaces ChaingunGuy
{
	mixin VoxelGore;
	Default { +DECOUPLEDANIMATIONS }
	override void BeginPlay() { Super.BeginPlay(); VG_Setup("models/chaingunner", "cg", 8); }
	States
	{
	Spawn:
		CPOS A 0 NoDelay A_SetAnimation('idle', flags: SAF_LOOP | SAF_NOOVERRIDE);
		CPOS A 10 A_Look;
		Wait;
	See:
		CPOS A 0 A_SetAnimation('walk', framerate: 46, flags: SAF_LOOP | SAF_NOOVERRIDE);
		CPOS AABBCCDD 3 A_Chase;
		Loop;
	Missile:
		CPOS E 0 A_SetAnimation('attack');
		CPOS E 10 A_FaceTarget;
	Fire:
		CPOS F 0 A_SetAnimation('fire', flags: SAF_LOOP | SAF_NOOVERRIDE);
		CPOS FE 4 BRIGHT A_CPosAttack;
		CPOS F 1 A_CPosRefire;
		Goto Fire;
	Pain:
		CPOS G 0 { SetAnimation(VG_PainAnim(), interpolateTics: 2); }
		CPOS G 3;
		CPOS G 3 A_Pain;
		CPOS G 6;
		Goto See;
	Death:
		CPOS H 0 { SetAnimation(VG_DeathAnim(), interpolateTics: 2); }
		CPOS H 5;
		CPOS I 5 A_Scream;
		CPOS J 5 A_NoBlocking;
		CPOS KLM 5;
		CPOS N -1;
		Stop;
	XDeath:
		CPOS O 0 VG_Burst;
		CPOS O 5;
		CPOS P 5 A_XScream;
		CPOS Q 5 A_NoBlocking;
		CPOS RS 5;
		CPOS T -1;
		Stop;
	Raise:
		CPOS N 0 VG_Heal;
		CPOS N 5;
		CPOS MLKJIH 5;
		Goto See;
	}
}
