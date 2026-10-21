// Revenant
class VoxelRevenant : Revenant replaces Revenant
{
	mixin VoxelGore;
	Default { +DECOUPLEDANIMATIONS GibHealth -90; }  // vanilla has no XDeath here; gib on a hard overkill
	override void BeginPlay() { Super.BeginPlay(); VG_Setup("models/revenant", "rv", 7); }
	States
	{
	Spawn:
		SKEL A 0 NoDelay A_SetAnimation('idle', flags: SAF_LOOP | SAF_NOOVERRIDE);
		SKEL A 10 A_Look;
		Wait;
	See:
		SKEL A 0 A_SetAnimation('walk', framerate: 46, flags: SAF_LOOP | SAF_NOOVERRIDE);
		SKEL AABBCCDDEEFF 2 A_Chase;
		Loop;
	Melee:
		SKEL G 0 { A_FaceTarget(); SetAnimation('melee'); }
		SKEL G 6 A_SkelWhoosh;
		SKEL H 6 A_FaceTarget;
		SKEL I 6 A_SkelFist;
		Goto See;
	Missile:
		SKEL J 0 BRIGHT { A_FaceTarget(); SetAnimation('attack'); }
		SKEL J 10 BRIGHT A_FaceTarget;
		SKEL K 10 A_SkelMissile;
		SKEL K 10 A_FaceTarget;
		Goto See;
	Pain:
		SKEL L 0 { SetAnimation(VG_PainAnim(), interpolateTics: 2); }
		SKEL L 5;
		SKEL L 5 A_Pain;
		Goto See;
	Death:
		SKEL L 0 { SetAnimation(VG_DeathAnim(), interpolateTics: 2); }
		SKEL LM 7;
		SKEL N 7 A_Scream;
		SKEL O 7 A_NoBlocking;
		SKEL P 7;
		SKEL Q -1;
		Stop;
	XDeath:
		SKEL L 0 VG_Burst;
		SKEL LM 7;
		SKEL N 7 A_XScream;
		SKEL O 7 A_NoBlocking;
		SKEL P 7;
		SKEL Q -1;
		Stop;
	Raise:
		SKEL Q 0 VG_Heal;
		SKEL Q 5;
		SKEL PONML 5;
		Goto See;
	}
}
