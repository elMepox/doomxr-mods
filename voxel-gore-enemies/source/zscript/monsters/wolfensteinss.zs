// Wolfenstein SS
class VoxelWolfensteinSS : WolfensteinSS replaces WolfensteinSS
{
	mixin VoxelGore;
	Default { +DECOUPLEDANIMATIONS }
	override void BeginPlay() { Super.BeginPlay(); VG_Setup("models/wolfss", "ss", 7); }
	States
	{
	Spawn:
		SSWV A 0 NoDelay A_SetAnimation('idle', flags: SAF_LOOP | SAF_NOOVERRIDE);
		SSWV A 10 A_Look;
		Wait;
	See:
		SSWV A 0 A_SetAnimation('walk', framerate: 46, flags: SAF_LOOP | SAF_NOOVERRIDE);
		SSWV AABBCCDD 3 A_Chase;
		Loop;
	Missile:
		SSWV E 0 A_SetAnimation('attack');
		SSWV E 10 A_FaceTarget;
	Burst:
		SSWV F 10 A_FaceTarget;
		SSWV G 0 A_SetAnimation('attack', startFrame: 14);
		SSWV G 4 BRIGHT A_CPosAttack;
		SSWV F 6 A_FaceTarget;
		SSWV G 0 A_SetAnimation('attack', startFrame: 14);
		SSWV G 4 BRIGHT A_CPosAttack;
		SSWV F 1 A_CPosRefire;
		Goto Burst;
	Pain:
		SSWV H 0 { SetAnimation(VG_PainAnim(), interpolateTics: 2); }
		SSWV H 3;
		SSWV H 3 A_Pain;
		SSWV H 6;
		Goto See;
	Death:
		SSWV I 0 { SetAnimation(VG_DeathAnim(), interpolateTics: 2); }
		SSWV I 5;
		SSWV J 5 A_Scream;
		SSWV K 5 A_NoBlocking;
		SSWV L 20;
		SSWV M -1;
		Stop;
	XDeath:
		SSWV N 0 VG_Burst;
		SSWV N 5;
		SSWV O 5 A_XScream;
		SSWV P 5 A_NoBlocking;
		SSWV QRSTU 5;
		SSWV V -1;
		Stop;
	Raise:
		SSWV M 0 VG_Heal;
		SSWV M 5;
		SSWV LKJI 5;
		Goto See;
	}
}
