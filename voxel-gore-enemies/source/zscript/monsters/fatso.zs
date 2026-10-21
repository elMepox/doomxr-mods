// Mancubus: a 2.2 m slab of fat on short legs with a flame cannon for each forearm. The head sits low
// between the shoulders and the legs are short, so both zone bands are narrower than on the humanoids.
// Arm hits play their own pain (the cannon arm is wrenched back).
class VoxelFatso : Fatso replaces Fatso
{
	mixin VoxelGore;
	Default { +DECOUPLEDANIMATIONS GibHealth -300; }  // vanilla has no XDeath here; gib on a hard overkill
	override void BeginPlay()
	{
		Super.BeginPlay();
		VG_Setup("models/mancubus", "mc", 22);
		vgHeadZ = 0.8; vgLegsZ = 0.27;
		VG_Zone(Z_ARM_L, "arm_l", VGS_BLOOD, 1, 'None', 'pain_arm_l');
		VG_Zone(Z_ARM_R, "arm_r", VGS_BLOOD, 1, 'None', 'pain_arm_r');
	}
	States
	{
	Spawn:
		FATT A 0 NoDelay A_SetAnimation('idle', flags: SAF_LOOP | SAF_NOOVERRIDE);
		FATT AB 15 A_Look;
		Loop;
	See:
		FATT A 0 A_SetAnimation('walk', flags: SAF_LOOP | SAF_NOOVERRIDE);
		FATT AABBCCDDEEFF 4 A_Chase;
		Loop;
	Missile:
		// attack: 20 tics raise, volleys on tics 21 (right), 41 (left), 61 (both), 80 tics in all
		FATT G 0 SetAnimation('attack');
		FATT G 20 A_FatRaise;
		FATT H 10 Bright A_FatAttack1;
		FATT IG 5 A_FaceTarget;
		FATT H 10 Bright A_FatAttack2;
		FATT IG 5 A_FaceTarget;
		FATT H 10 Bright A_FatAttack3;
		FATT IG 5 A_FaceTarget;
		Goto See;
	Pain:
		FATT J 0 { SetAnimation(VG_PainAnim(), interpolateTics: 2); }
		FATT J 3;
		FATT J 3 A_Pain;
		FATT J 6;
		Goto See;
	Death:
		FATT K 0 { SetAnimation(VG_DeathAnim(), interpolateTics: 2); }
		FATT K 6;
		FATT L 6 A_Scream;
		FATT M 6 A_NoBlocking;
		FATT NOPQRS 6;
		FATT T -1 A_BossDeath;
		Stop;
	XDeath:
		FATT K 0 VG_Burst;
		FATT K 6;
		FATT L 6 A_XScream;
		FATT M 6 A_NoBlocking;
		FATT NOPQRS 6;
		FATT T -1 A_BossDeath;
		Stop;
	Raise:
		FATT T 0 VG_Heal;
		FATT R 5;
		FATT QPONMLK 5;
		Goto See;
	}
}
