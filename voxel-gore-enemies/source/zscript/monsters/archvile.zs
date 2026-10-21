// Arch-vile
class VoxelArchvile : Archvile replaces Archvile
{
	mixin VoxelGore;
	Default { +DECOUPLEDANIMATIONS GibHealth -200; }  // vanilla has no XDeath here; gib on a hard overkill
	override void BeginPlay() { Super.BeginPlay(); VG_Setup("models/archvile", "av", 8); }
	States
	{
	Spawn:
		VILE A 0 NoDelay A_SetAnimation('idle', flags: SAF_LOOP | SAF_NOOVERRIDE);
		VILE A 10 A_Look;
		Wait;
	See:
		VILE A 0 A_SetAnimation('walk', framerate: 60, flags: SAF_LOOP | SAF_NOOVERRIDE);
		VILE AABBCCDDEEFF 2 A_VileChase;
		Loop;
	Missile:
		VILE G 0 BRIGHT { A_VileStart(); SetAnimation('attack'); }
		VILE G 10 BRIGHT A_FaceTarget;
		VILE H 8 BRIGHT A_VileTarget;
		VILE IJKLMN 8 BRIGHT A_FaceTarget;
		VILE O 8 BRIGHT A_VileAttack;
		VILE P 20 BRIGHT;
		Goto See;
	Heal:
		VILE [ 0 BRIGHT A_SetAnimation('heal');
		VILE [\] 10 BRIGHT;
		Goto See;
	Pain:
		VILE Q 0 { SetAnimation(VG_PainAnim(), interpolateTics: 2); }
		VILE Q 5;
		VILE Q 5 A_Pain;
		Goto See;
	Death:
		VILE Q 0 { SetAnimation(VG_DeathAnim(), interpolateTics: 2); }
		VILE Q 7;
		VILE R 7 A_Scream;
		VILE S 7 A_NoBlocking;
		VILE TUVWXY 7;
		VILE Z -1;
		Stop;
	XDeath:
		VILE Q 0 VG_Burst;
		VILE Q 7;
		VILE R 7 A_XScream;
		VILE S 7 A_NoBlocking;
		VILE TUVWXY 7;
		VILE Z -1;
		Stop;
	}
}
