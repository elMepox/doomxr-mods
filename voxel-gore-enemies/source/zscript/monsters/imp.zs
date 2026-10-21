// Imp
class VoxelImp : DoomImp replaces DoomImp
{
	mixin VoxelGore;
	Default { +DECOUPLEDANIMATIONS }
	override void BeginPlay() { Super.BeginPlay(); VG_Setup("models/imp", "imp", 7); }
	States
	{
	Spawn:
		TROO A 0 NoDelay A_SetAnimation('idle', flags: SAF_LOOP | SAF_NOOVERRIDE);
		TROO A 10 A_Look;
		Wait;
	See:
		TROO A 0 A_SetAnimation('walk', framerate: 46, flags: SAF_LOOP | SAF_NOOVERRIDE);
		TROO AABBCCDD 3 A_Chase;
		Loop;
	Melee:
	Missile:
		TROO E 0 { SetAnimation(CheckMeleeRange() ? 'melee' : 'attack', framerate: CheckMeleeRange() ? 35 : 40); }
		TROO EF 8 A_FaceTarget;
		TROO G 6 A_TroopAttack;
		Goto See;
	Pain:
		TROO H 0 { SetAnimation(VG_PainAnim(), interpolateTics: 2); }
		TROO H 2;
		TROO H 2 A_Pain;
		TROO H 6;
		Goto See;
	Death:
		TROO I 0 { SetAnimation(VG_DeathAnim(), interpolateTics: 2); }
		TROO I 8;
		TROO J 8 A_Scream;
		TROO K 6;
		TROO L 6 A_NoBlocking;
		TROO M -1;
		Stop;
	XDeath:
		TROO N 0 VG_Burst;
		TROO N 5;
		TROO O 5 A_XScream;
		TROO P 5;
		TROO Q 5 A_NoBlocking;
		TROO RST 5;
		TROO U -1;
		Stop;
	Raise:
		TROO M 0 VG_Heal;
		TROO ML 8;
		TROO KJI 6;
		Goto See;
	}
}
