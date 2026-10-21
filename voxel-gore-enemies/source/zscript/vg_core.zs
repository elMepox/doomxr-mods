// Voxel Gore: enemies as voxel IQM models with hit zones, live zone damage (A_ChangeModel),
// voxel blood particles and zone/type-aware deaths.
// Shared logic lives in the VoxelGore mixin; each enemy class (zscript/monsters/*.zs) only sets its
// model, zone layout and states.
//
// Every enemy has up to 5 model slots (MODELDEF Model 0..4), one per zone, each <prefix>_<zone>_0.iqm
// (intact) and _1.iqm (wounded). What a slot means depends on the layout:
//   VGL_BIPED   0 head, 1 torso, 2 arm_l, 3 arm_r, 4 legs   (height of the hit + side; the nine humanoids)
//   VGL_ORB     0 front centre (eye/face), 1 shell (the rest), 2 left side, 3 right side, 4 front low (mouth)
//   VGL_SPIDER  0 top (brain), 1 chassis, 2 legs on the left, 3 legs on the right, 4 front (gun)
// Zone names are per class (VG_Zone), so the files can be called cacodemon_eye_1.iqm and so on.
// A slot with no name is not used by that enemy; hits there count for vgFallbackZone.

enum EVGLayout { VGL_BIPED, VGL_ORB, VGL_SPIDER };
enum EVGSpray { VGS_BLOOD, VGS_BONE, VGS_METAL, VGS_FIRE };

mixin class VoxelGore
{
	enum EZone { Z_HEAD, Z_TORSO, Z_ARM_L, Z_ARM_R, Z_LEGS, NUM_ZONES };

	string vgPath, vgPrefix;  // models/<enemy>, file prefix (zm, sg, cg, ...)
	double vgArmSide;         // map units from the center line where the arms start
	int vgBreak;              // damage a zone takes before it switches to its wounded model
	int lastZone;
	double lastSide;          // >0: hit from the front, <0: from behind
	int zoneDamage[NUM_ZONES];
	bool zoneBroken[NUM_ZONES];
	bool vgBlast;             // last hit was an explosion (rocket, barrel, A_Explode)
	Vector3 vgBlastFrom;      // where it went off: the body is thrown away from it

	int vgLayout;                 // EVGLayout
	double vgHeadZ, vgLegsZ;      // BIPED: above vgHeadZ of the height = head, below vgLegsZ = legs
	int vgFallbackZone;           // zone for hits on an unused slot
	string vgZoneNames[NUM_ZONES];
	int vgZoneSpray[NUM_ZONES];   // EVGSpray: what flies out of a hit there
	double vgZoneMul[NUM_ZONES];  // damage multiplier (headshot x2)
	Name vgZoneDeath[NUM_ZONES];  // death animation for a kill there; 'None' = death_back / death_front by side
	Name vgZonePain[NUM_ZONES];
	int vgBurstSpray;             // spray of the gib burst

	// Note: every Spawn state starts with NoDelay A_SetAnimation('idle'). GZDoom draws a decoupled model
	// that has no animation yet with whatever bone offset the previous model left, so a monster whose
	// first state action never ran got skinned by another actor's skeleton (a tall stretched "pillar").
	// The defaults are the humanoid setup; non-humanoids call VG_Layout / VG_Zone after this.
	void VG_Setup(string path, string prefix, double armSide)
	{
		vgPath = path; vgPrefix = prefix; vgArmSide = armSide;
		vgBreak = max(8, int(GetSpawnHealth() * 0.15));
		// bosses (Cyberdemon, Spider Mastermind) have thousands of health: wounds have to show during the fight
		if (bBoss) vgBreak = min(vgBreak, 150);
		vgLayout = VGL_BIPED; vgHeadZ = 0.82; vgLegsZ = 0.5;
		vgFallbackZone = Z_TORSO; vgBurstSpray = VGS_BLOOD;
		VG_Zone(Z_HEAD,  "head",  VGS_BLOOD, bBoss ? 1 : 2, 'death_head', 'pain_head');
		VG_Zone(Z_TORSO, "torso", VGS_BLOOD, 1, 'None', 'pain_torso');
		VG_Zone(Z_ARM_L, "arm_l", VGS_BLOOD, 1, 'None', 'pain_torso');
		VG_Zone(Z_ARM_R, "arm_r", VGS_BLOOD, 1, 'None', 'pain_torso');
		VG_Zone(Z_LEGS,  "legs",  VGS_BLOOD, 1, 'death_legs', 'pain_legs');
	}

	void VG_Layout(int layout, int fallback = Z_TORSO)
	{
		vgLayout = layout; vgFallbackZone = fallback;
	}

	// name "" switches the slot off
	void VG_Zone(int z, string name, int spray = VGS_BLOOD, double mul = 1, Name death = 'None', Name pain = 'pain_torso')
	{
		vgZoneNames[z] = name; vgZoneSpray[z] = spray; vgZoneMul[z] = mul;
		vgZoneDeath[z] = death; vgZonePain[z] = pain;
	}

	// kept for the test map and older callers: the humanoid slot names
	static clearscope string VG_ZoneName(int z)
	{
		static const string names[] = { "head", "torso", "arm_l", "arm_r", "legs" };
		return names[z];
	}

	string VG_ZoneModel(int z, int level)
	{
		return vgPrefix .. "_" .. vgZoneNames[z] .. "_" .. level .. ".iqm";
	}

	// Height of the hit: projectiles/puffs give it directly, plain hitscan is re-traced from the shooter.
	Vector3 VG_HitPoint(Actor inflictor, Actor source)
	{
		if (inflictor && inflictor != source)
			return inflictor.Pos + (0, 0, inflictor.Height * 0.5);
		if (source)
		{
			FLineTraceData t;
			double z = source.player ? source.Height * 0.5 - source.Floorclip + source.player.mo.AttackZOffset * source.player.crouchfactor : source.Height * 0.5;
			if (source.LineTrace(source.Angle, 4096, source.Pitch, TRF_ALLACTORS, z, 0, 0, t) && t.HitActor == self)
				return t.HitLocation;
		}
		return Pos + (0, 0, Height * 0.55);
	}

	int VG_ZoneAt(Vector3 hit)
	{
		int z;
		if (vgLayout == VGL_ORB) z = VG_OrbZone(hit);
		else if (vgLayout == VGL_SPIDER) z = VG_SpiderZone(hit);
		else z = VG_BipedZone(hit);
		return vgZoneNames[z] == "" ? vgFallbackZone : z;
	}

	int VG_BipedZone(Vector3 hit)
	{
		double relZ = (hit.z - Pos.z) / Height;
		Vector2 d = hit.xy - Pos.xy;
		double side = d dot AngleToVector(Angle + 90);   // + = monster's left
		if (relZ > vgHeadZ) return Z_HEAD;
		if (relZ < vgLegsZ) return Z_LEGS;
		if (side > vgArmSide) return Z_ARM_L;
		if (side < -vgArmSide) return Z_ARM_R;
		return Z_TORSO;
	}

	// A floating ball: where on it, seen from its own facing. The hit point lies on the bounding box.
	int VG_OrbZone(Vector3 hit)
	{
		Vector2 d = hit.xy - Pos.xy;
		double fwd = (d dot AngleToVector(Angle)) / Radius;
		double side = (d dot AngleToVector(Angle + 90)) / Radius;
		double up = (hit.z - Pos.z - Height * 0.5) / (Height * 0.5);
		if (fwd > 0.3 && abs(side) < 0.45)
		{
			if (up < -0.2) return 4;          // mouth, low on the front
			if (up < 0.7) return 0;           // eye / face
		}
		if (side > 0.45) return 2;
		if (side < -0.45) return 3;
		return 1;
	}

	// A walker on four legs: legs low and out to the sides, brain on top, gun at the front.
	int VG_SpiderZone(Vector3 hit)
	{
		double relZ = (hit.z - Pos.z) / Height;
		Vector2 d = hit.xy - Pos.xy;
		double fwd = (d dot AngleToVector(Angle)) / Radius;
		double side = (d dot AngleToVector(Angle + 90)) / Radius;
		if (relZ > 0.7) return 0;
		// legs: everything low, plus the thighs sticking out at the sides at mid height
		if (relZ < 0.4 || abs(side) > 0.65) return side >= 0 ? 2 : 3;
		if (fwd > 0.3 && abs(side) < 0.35) return 4;
		return 1;
	}

	void VG_Blood(Vector3 at, double dir, int count)
	{
		VG_Spray(VGS_BLOOD, at, dir, count);
	}

	void VG_Spray(int kind, Vector3 at, double dir, int count)
	{
		color base = BloodColor;
		bool red = base == 0 || base == -1;
		TextureID none = TexMan.CheckForTexture("");
		Vector3 o = at - Pos;
		for (int i = 0; i < count; i++)
		{
			double a = dir + frandom(-35, 35);
			double s = frandom(1.5, 5);
			double k = frandom(0.45, 0.75);
			if (kind == VGS_METAL)
			{
				// sparks: short, fast, bright; every few a dark metal chip that drops
				if (i % 4)
					A_SpawnParticleEx(Color(255, 255, random(170, 230), random(60, 120)), none, STYLE_Add, SPF_FULLBRIGHT, random(6, 14),
						frandom(1, 2) * Radius / 20.0, 0, o.x, o.y, o.z, cos(a) * s * 1.6, sin(a) * s * 1.6, frandom(1, 5), 0, 0, -0.4);
				else
				{
					int g = random(55, 95);
					A_SpawnParticleEx(Color(255, g, g, g + 8), none, STYLE_Normal, 0, random(25, 45),
						frandom(2, 3) * Radius / 20.0, 0, o.x, o.y, o.z, cos(a) * s, sin(a) * s, frandom(1, 4), 0, 0, -0.6);
				}
				continue;
			}
			if (kind == VGS_FIRE)
			{
				A_SpawnParticleEx(Color(255, 255, random(90, 180), random(0, 40)), none, STYLE_Add, SPF_FULLBRIGHT, random(10, 24),
					frandom(2, 4) * Radius / 20.0, -0.15, o.x, o.y, o.z, cos(a) * s * 0.6, sin(a) * s * 0.6, frandom(1, 3), 0, 0, 0.15);
				continue;
			}
			color c;
			if (kind == VGS_BONE) { int g = random(150, 225); c = Color(255, g, g - random(5, 20), g - random(25, 45)); }
			else c = red ? Color(255, random(110, 190), 8, 8) : Color(255, int(base.r * k), int(base.g * k), int(base.b * k));
			A_SpawnParticleEx(c, none, STYLE_Normal, 0, random(20, 45),
				frandom(2, 4) * Radius / 20.0, 0,
				o.x, o.y, o.z,
				cos(a) * s, sin(a) * s, frandom(0.5, 4),
				0, 0, -0.5);
		}
	}

	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		{
			Vector3 hit = VG_HitPoint(inflictor, source);
			lastZone = VG_ZoneAt(hit);
			Actor from = inflictor ? inflictor : source;
			lastSide = from ? cos(DeltaAngle(Angle, AngleTo(from))) : 1;
			vgBlast = mod == 'Explosive' || (flags & DMG_EXPLOSION);
			if (vgBlast) vgBlastFrom = from ? from.Pos : Pos;
			else if (vgZoneMul[lastZone] != 1) damage = int(damage * vgZoneMul[lastZone]);   // headshot bonus
			double away = from ? from.AngleTo(self) : Angle + 180;
			int spray = vgZoneSpray[lastZone];
			VG_Spray(spray, hit, away, 20 + min(damage, 60) * (vgBlast ? 3 : 2));

			zoneDamage[lastZone] += damage;
			if (!zoneBroken[lastZone] && zoneDamage[lastZone] >= vgBreak)
			{
				zoneBroken[lastZone] = true;
				A_ChangeModel("", lastZone, vgPath, VG_ZoneModel(lastZone, 1));
				VG_Spray(spray, hit, away, 60);
			}
		}
		return Super.DamageMobj(inflictor, source, damage, mod, flags, angle);
	}

	// Arch-vile resurrection: wounds close, zones go back to the intact models.
	void VG_Heal()
	{
		for (int z = 0; z < NUM_ZONES; z++)
		{
			if (zoneBroken[z])
				A_ChangeModel("", z, vgPath, VG_ZoneModel(z, 0));
			zoneBroken[z] = false;
			zoneDamage[z] = 0;
		}
		SetAnimation('idle', interpolateTics: 6, flags: SAF_LOOP);
	}

	Name VG_DeathAnim()
	{
		if (vgBlast)
		{
			// death_blast throws the body backwards: turn to face the explosion first
			Angle = VectorAngle(vgBlastFrom.x - Pos.x, vgBlastFrom.y - Pos.y);
			// death_blast already throws the body back; keep only a little of the kickback on top
			if (Vel.XY.Length() > 4) Vel.XY = Vel.XY.Unit() * 4;
			VG_Spray(vgBurstSpray, Pos + (0, 0, Height * 0.6), Angle + 180, 80);
			return 'death_blast';
		}
		Name d = vgZoneDeath[lastZone];
		if (d != 'None') return d;
		return lastSide >= 0 ? 'death_back' : 'death_front';
	}

	Name VG_PainAnim()
	{
		return vgZonePain[lastZone];
	}

	// Flyers (Cacodemon, Pain Elemental) lose NOGRAVITY when they die and drop. Their Death state plays
	// the zone death (a tumble in the air) and loops on VG_AirFall, which jumps to the given state and
	// plays death_land once the body hits the floor:  CACO G 1 { return VG_AirFall("DeathLand"); } Wait;
	state VG_AirFall(StateLabel land)
	{
		if (Pos.z > FloorZ + 1 && !bOnMobj) return null;
		SetAnimation('death_land', interpolateTics: 2);
		for (int i = 0; i < 4; i++)
			VG_Spray(vgBurstSpray, Pos + (0, 0, Height * 0.3), frandom(0, 360), 40);
		return ResolveState(land);
	}

	void VG_Burst()
	{
		// the pieces scatter in the animation itself; the explosion's kickback would carry the whole remains away
		Vel = (0, 0, 0);
		SetAnimation('death_explode', interpolateTics: 1);
		for (int i = 0; i < 6; i++)
			VG_Spray(vgBurstSpray, Pos + (0, 0, Height * frandom(0.2, 0.9)), frandom(0, 360), 60);
		// flying meat chunks with blood trails, more for bigger monsters
		int n = 8 + int(Radius / 4);
		double away = vgBlast ? VectorAngle(vgBlastFrom.x - Pos.x, vgBlastFrom.y - Pos.y) + 180 : frandom(0, 360);
		for (int i = 0; i < n; i++)
		{
			let g = VGGib(Spawn("VGGib", Pos + (frandom(-0.5, 0.5) * Radius, frandom(-0.5, 0.5) * Radius, Height * frandom(0.25, 0.85))));
			if (!g) continue;
			g.blood = BloodColor;
			g.bone = vgBurstSpray == VGS_BONE;
			g.size = frandom(6, 10) * Radius / 20.0;
			double a = vgBlast ? away + frandom(-70, 70) : frandom(0, 360);
			double s = frandom(3, 9);
			g.Vel = (cos(a) * s, sin(a) * s, frandom(4, 11));
		}
	}
}

// A chunk of meat thrown by a gib death: drawn as a voxel-sized particle with a blood trail,
// bounces on the floor and settles into a small stain.
class VGGib : Actor
{
	color blood;
	bool bone;       // a skull fragment: bone coloured, trails embers instead of blood
	double size;
	int life;
	bool landed;
	Default { Radius 2; Height 2; Gravity 0.8; +NOBLOCKMAP +DROPOFF +NOTELEPORT +THRUACTORS +NOTONAUTOMAP }
	States { Spawn: TNT1 A -1; Stop; }

	color Meat(double k)
	{
		if (bone) { int g = int(random(150, 210) * k); return Color(255, g, g - 12, g - 38); }
		bool red = blood == 0 || blood == -1;
		return red ? Color(255, int(random(120, 165) * k), int(18 * k), int(14 * k))
		           : Color(255, int(blood.r * 0.6 * k), int(blood.g * 0.6 * k), int(blood.b * 0.6 * k));
	}
	override void Tick()
	{
		Super.Tick();
		if (++life > 140) { Destroy(); return; }
		if (!landed && Pos.z <= FloorZ + 0.5 && Vel.z <= 0)
		{
			Vel.z = -Vel.z * 0.3; Vel.xy *= 0.55;
			if (Vel.z < 1.5) { Vel = (0, 0, 0); landed = true; bNoGravity = true; }
		}
		A_SpawnParticleEx(Meat(1), TexMan.CheckForTexture(""), STYLE_Normal, 0, 2, size, 0, 0, 0, size * 0.5);
		if (!landed && bone && life % 2 == 0)
			A_SpawnParticleEx(Color(255, 255, random(90, 170), 20), TexMan.CheckForTexture(""), STYLE_Add, SPF_FULLBRIGHT, random(8, 16), size * 0.6, 0,
				frandom(-1, 1), frandom(-1, 1), 0, 0, 0, 0.3);
		else if (!landed && life % 2 == 0)
			A_SpawnParticleEx(Meat(0.8), TexMan.CheckForTexture(""), STYLE_Normal, 0, random(20, 40), size * 0.5, 0,
				frandom(-1, 1), frandom(-1, 1), 0, 0, 0, 0, 0, 0, -0.4);
	}
}
