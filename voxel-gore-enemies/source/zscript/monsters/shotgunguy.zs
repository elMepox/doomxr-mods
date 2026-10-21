// Shotgun Guy
class VoxelShotgunGuy : ShotgunGuy replaces ShotgunGuy
{
	mixin VoxelGore;
	Default { +DECOUPLEDANIMATIONS }
	override void BeginPlay() { Super.BeginPlay(); VG_Setup("models/shotgunguy", "sg", 7); }
	States
	{
	Spawn:
		SPOS A 0 NoDelay A_SetAnimation('idle', flags: SAF_LOOP | SAF_NOOVERRIDE);
		SPOS A 10 A_Look;
		Wait;
	See:
		SPOS A 0 A_SetAnimation('walk', framerate: 46, flags: SAF_LOOP | SAF_NOOVERRIDE);
		SPOS AABBCCDD 3 A_Chase;
		Loop;
	Missile:
		SPOS E 0 A_SetAnimation('attack', framerate: 30);
		SPOS E 10 A_FaceTarget;
		SPOS F 10 BRIGHT A_SposAttackUseAtkSound;
		SPOS E 10;
		Goto See;
	Pain:
		SPOS G 0 { SetAnimation(VG_PainAnim(), interpolateTics: 2); }
		SPOS G 3;
		SPOS G 3 A_Pain;
		SPOS G 6;
		Goto See;
	Death:
		SPOS H 0 { SetAnimation(VG_DeathAnim(), interpolateTics: 2); }
		SPOS H 5;
		SPOS I 5 A_Scream;
		SPOS J 5 A_NoBlocking;
		SPOS K 20;
		SPOS L -1;
		Stop;
	XDeath:
		SPOS M 0 VG_Burst;
		SPOS M 5;
		SPOS N 5 A_XScream;
		SPOS O 5 A_NoBlocking;
		SPOS PQRST 5;
		SPOS U -1;
		Stop;
	Raise:
		SPOS L 0 VG_Heal;
		SPOS L 5;
		SPOS KJIH 5;
		Goto See;
	}
}
