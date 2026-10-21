version "4.12"

// Voxel Gore blood add-on (P1 "world in blood"). Load after voxel_gore_enemies.pk3, or alone with any monsters.
// Everything is driven by one EventHandler, so the enemy classes stay untouched:
//   hits    -> voxel drops that fly, splat on walls and pool on the floor; pixel splats on the wall behind;
//              heavy hits splat the ceiling, which then drips
//   wounded -> monsters below 60% health leave a trail of drops
//   deaths  -> a voxel pool spreads under the body; gibs throw persistent voxel meat chunks
//   close   -> blood drops on the screen
// Blood, pools and chunks stay forever unless vg_pools_max / vg_gibs_max / vg_splats_max are set.

enum EVGFamily { VGF_RED, VGF_GREEN, VGF_BLUE };

class VGBlood play
{
	static int Family(Actor a)
	{
		color c = a.BloodColor;
		if (c == 0 || c == -1) return VGF_RED;
		if (c.g > c.r && c.g >= c.b) return VGF_GREEN;
		if (c.b > c.r && c.b > c.g) return VGF_BLUE;
		return VGF_RED;
	}
	static clearscope string FamName(int f) { static const string n[] = { "red", "green", "blue" }; return n[f]; }
	static clearscope string FamLetter(int f) { static const string n[] = { "R", "G", "B" }; return n[f]; }

	static color Tone(int fam, double k)
	{
		static const int r[] = { 150, 34, 16 };
		static const int g[] = { 14, 110, 34 };
		static const int b[] = { 10, 16, 140 };
		return Color(255, int(r[fam] * k), int(g[fam] * k), int(b[fam] * k));
	}

	static double Amount() { return clamp(CVar.FindCVar('vg_blood').GetInt(), 0, 4) / 2.0; }
}

// ---------------------------------------------------------------- drop: one voxel of blood in flight
class VGDrop : Actor
{
	int fam;
	double size;
	Vector3 lastVel;
	Default
	{
		Radius 1; Height 1; Speed 1; Gravity 0.7;
		Projectile; -NOGRAVITY; +THRUACTORS +NOTELEPORT +BLOODLESSIMPACT +NOTONAUTOMAP +DROPOFF;
	}
	States
	{
	Spawn: TNT1 A -1; Stop;
	Death: TNT1 A 0 Land; Stop;
	}
	override void Tick()
	{
		lastVel = Vel;
		Super.Tick();
		if (!bDestroyed && !InStateSequence(CurState, ResolveState("Death")))
			A_SpawnParticleEx(VGBlood.Tone(fam, frandom(0.75, 1.05)), TexMan.CheckForTexture(""), STYLE_Normal, 0, 2, size);
	}
	void Land()
	{
		let h = VGBloodHandler(EventHandler.Find("VGBloodHandler"));
		if (BlockingLine && lastVel.xy.Length() > 0.5)
		{
			Vector3 dir = lastVel.Unit();
			A_SprayDecal("VGSplat" .. VGBlood.FamLetter(fam), 24, (0, 0, 0), dir);
		}
		else if (Pos.z <= FloorZ + 2 && h)
			h.FloorBlood(Pos.xy, fam);
	}
}

// ---------------------------------------------------------------- floor pool: spreads in voxel steps
class VGPool : Actor
{
	int fam, shape, stage, target, nextGrow;
	string sz;          // s, m, l, h
	int growDelay;
	Default { Radius 2; Height 1; +NOINTERACTION +NOTONAUTOMAP +NOBLOCKMAP +MOVEWITHSECTOR; }
	States { Spawn: VGBL A -1; Stop; }

	static const double SIZES[] = { 25, 63, 90, 126 };
	static int SizeIndex(string s) { return s == "s" ? 0 : s == "m" ? 1 : s == "l" ? 2 : 3; }
	double RadiusAt(int st) { return SIZES[SizeIndex(sz)] / 2 * (0.28 + 0.72 * (st + 1) / 8.0); }
	double CurRadius() { return RadiusAt(stage); }

	void Init(int f, string size, int startStage, int targetStage, int delay)
	{
		fam = f; sz = size; shape = random(0, 2); stage = startStage; target = targetStage;
		nextGrow = level.time + delay;
		growDelay = size == "s" ? 4 : random(10, 16);
		Angle = frandom(0, 360);
		SetModel();
	}
	void SetModel()
	{
		// one flat quad per size; shape, growth stage and colour live in the pixel texture (1 texel = 1 voxel)
		A_ChangeModel("", 0, "models/blood", "pool_" .. sz .. ".obj", 0, "models/blood", "pool_" .. sz .. shape .. "_" .. stage .. "_" .. VGBlood.FamName(fam) .. ".png");
	}
	void Grow(int st)
	{
		target = clamp(max(target, st), 0, 7);
		if (nextGrow < level.time) nextGrow = level.time;
	}
	override void Tick()
	{
		// a finished pool does nothing at all; only growth and moving floors cost anything
		if (stage < target && level.time >= nextGrow)
		{
			stage++;
			nextGrow = level.time + growDelay;
			SetModel();
		}
		if (CurSector && CurSector.floordata && (level.time & 7) == 0)
			SetZ(CurSector.floorplane.ZatPoint(Pos.xy) + 0.05);
	}
}

// ---------------------------------------------------------------- ceiling splat: hangs and drips for a while
class VGCeilSplat : Actor
{
	int fam, dripsLeft, nextDrip;
	Default { Radius 2; Height 1; +NOINTERACTION +NOTONAUTOMAP +NOBLOCKMAP +NOGRAVITY; }
	States { Spawn: VGBL A -1; Stop; }
	void Init(int f)
	{
		fam = f; Angle = frandom(0, 360);
		dripsLeft = random(8, 20); nextDrip = level.time + random(10, 30);
		int n = random(0, 3);
		A_ChangeModel("", 0, "models/blood", "ceil_" .. n .. ".obj", 0, "models/blood", "ceil_" .. n .. "_" .. VGBlood.FamName(fam) .. ".png");
	}
	override void Tick()
	{
		if (dripsLeft > 0 && level.time >= nextDrip)
		{
			dripsLeft--;
			nextDrip = level.time + random(15, 45);
			let d = VGDrop(Spawn("VGDrop", Pos + (frandom(-12, 12), frandom(-12, 12), -4)));
			if (d) { d.fam = fam; d.size = 1.6; d.Vel = (0, 0, -1); }
		}
	}
}

// ---------------------------------------------------------------- meat chunk: a voxel model that stays
class VGChunk : Actor
{
	int fam, kind;
	double spinP, spinR;
	bool landed, splatted;
	Default { Radius 2; Height 2; Gravity 0.8; +NOBLOCKMAP +DROPOFF +NOTELEPORT +THRUACTORS +NOTONAUTOMAP +MOVEWITHSECTOR; }
	States { Spawn: VGBL A -1; Stop; }
	// half height of each chunk model (map units), so a landed chunk rests on the floor
	static const double HALF[] = { 2.72, 1.63, 3.27, 2.18, 1.63, 2.72, 2.72, 0.54, 1.63, 1.63 };

	void Init(int f)
	{
		fam = f; kind = random(0, 9);
		Angle = frandom(0, 360); Pitch = frandom(0, 360); Roll = frandom(0, 360);
		spinP = frandom(-25, 25); spinR = frandom(-25, 25);
		A_ChangeModel("", 0, "models/blood", "chunk_" .. kind .. ".obj", 0, "models/blood", "vgb_" .. VGBlood.FamName(fam) .. ".png");
	}
	override void Tick()
	{
		if (landed)
		{
			if (CurSector && CurSector.floordata && (level.time & 7) == 0) SetZ(CurSector.floorplane.ZatPoint(Pos.xy) + HALF[kind]);
			return;
		}
		Super.Tick();
		if (bDestroyed) return;
		Pitch += spinP; Roll += spinR;
		if (BlockingLine && !splatted)
		{
			splatted = true;
			A_SprayDecal("VGSplat" .. VGBlood.FamLetter(fam), 32, (0, 0, 0), (Vel.xy.Unit(), 0));
			Vel.xy *= -0.3;
		}
		if (level.time & 1)
			A_SpawnParticleEx(VGBlood.Tone(fam, 0.8), TexMan.CheckForTexture(""), STYLE_Normal, 0, random(20, 40), 1.5, 0,
				frandom(-1, 1), frandom(-1, 1), 0, 0, 0, 0, 0, 0, -0.4);
		if (Pos.z <= FloorZ + 0.5 && Vel.z <= 0)
		{
			Vel.z = -Vel.z * 0.3; Vel.xy *= 0.5;
			spinP *= 0.5; spinR *= 0.5;
			if (Vel.z < 1.5)
			{
				// settle lying flat on one side of the voxel block
				landed = true; Vel = (0, 0, 0); bNoGravity = true;
				// rest on the flat side: the model's half height is along z only when pitch and roll are 0 or 180
				Pitch = 180 * round(Pitch / 180); Roll = 180 * round(Roll / 180);
				SetZ(FloorZ + HALF[kind]);
				let h = VGBloodHandler(EventHandler.Find("VGBloodHandler"));
				if (h) h.FloorBlood(Pos.xy, fam, 3);
			}
		}
	}
}

// ---------------------------------------------------------------- handler
class VGPoolCell { Array<VGPool> pools; }

class VGBloodHandler : EventHandler
{
	Array<Actor> pools, chunks, ceils;
	Array<Actor> bleeders;
	Map<int, VGPoolCell> grid;          // 128-unit cells -> pools, to merge new drops into nearby pools
	Actor lastDied; int lastDiedTic;
	Array<Actor> pendingGibs; Array<Actor> pendingOwners;

	// screen blood (read by RenderOverlay)
	Array<int> scrTime; Array<double> scrX, scrY, scrSize; Array<int> scrTex, scrFam, scrPlayer;

	static const double POOLR[] = { 25, 63, 90, 126 };

	// ------------------------------------------------ limits
	void Keep(Array<Actor> list, Actor a, Name cvName)
	{
		list.Push(a);
		int lim = CVar.FindCVar(cvName).GetInt();
		while (lim > 0 && list.Size() > lim)
		{
			if (list[0]) list[0].Destroy();
			list.Delete(0);
		}
	}

	// ------------------------------------------------ pools
	int CellKey(Vector2 p) { return (int(floor(p.x / 128)) & 0xffff) | (int(floor(p.y / 128)) << 16); }

	VGPool NearPool(Vector2 p)
	{
		VGPool best; double bd = 1e9;
		for (int dx = -1; dx <= 1; dx++)
		for (int dy = -1; dy <= 1; dy++)
		{
			let c = grid.GetIfExists(CellKey(p + (dx * 128, dy * 128)));
			if (!c) continue;
			for (int i = 0; i < c.pools.Size(); i++)
			{
				let pl = c.pools[i];
				if (!pl) continue;
				double d = (pl.Pos.xy - p).Length();
				if (d < pl.CurRadius() * 0.9 && d < bd) { bd = d; best = pl; }
			}
		}
		return best;
	}

	bool FlatEnough(Vector2 at, double z, double r)
	{
		for (int i = 0; i < 8; i++)
		{
			Vector2 p = at + Actor.AngleToVector(i * 45) * r;
			let s = level.PointInSector(p);
			if (abs(s.floorplane.ZatPoint(p) - z) > 3) return false;
		}
		return true;
	}

	VGPool SpawnPool(Vector2 at, int fam, string size, int stage0, int stage1, int delay)
	{
		let s = level.PointInSector(at);
		double z = s.floorplane.ZatPoint(at);
		if (s.GetFloorTerrain(0).IsLiquid) return null;
		if (s.floorplane.Normal.z < 0.99) size = "s";                  // slopes: small flat pools only
		// shrink until it does not hang over a ledge
		static const string order[] = { "h", "l", "m", "s" };
		int k = size == "h" ? 0 : size == "l" ? 1 : size == "m" ? 2 : 3;
		while (k < 3 && !FlatEnough(at, z, POOLR[3 - k] / 2 * 0.85)) k++;
		size = order[k];
		let p = VGPool(Actor.Spawn("VGPool", (at, z + frandom(0.02, 0.25))));
		if (!p) return null;
		p.Init(fam, size, stage0, stage1, delay);
		int key = CellKey(at);
		let c = grid.GetIfExists(key);
		if (!c) { c = new("VGPoolCell"); grid.Insert(key, c); }
		c.pools.Push(p);
		Keep(pools, p, 'vg_pools_max');
		return p;
	}

	// A drop or a chunk reached the floor: feed a nearby pool or start a small one.
	void FloorBlood(Vector2 at, int fam, int grow = 1)
	{
		let p = NearPool(at);
		if (p)
		{
			if (p.sz == "s") p.Grow(p.target + grow);
			return;
		}
		SpawnPool(at, fam, "s", 0, grow - 1, 0);
	}

	// ------------------------------------------------ spawn helpers
	void Drops(Actor from, Vector3 at, double dir, int n, int fam, double spread = 40, double speed = 5)
	{
		for (int i = 0; i < n; i++)
		{
			let d = VGDrop(Actor.Spawn("VGDrop", at));
			if (!d) continue;
			d.fam = fam; d.size = frandom(1.2, 2.4);
			d.target = from;
			double a = dir + frandom(-spread, spread), s = frandom(0.3, 1) * speed;
			d.Vel = (cos(a) * s, sin(a) * s, frandom(0.5, 4));
		}
	}

	void WallSplat(Actor a, Vector3 at, double dir, int fam, bool big)
	{
		// trace from the hit away from the shooter; A_SprayDecal does the trace and only paints a wall
		Vector3 d = (cos(dir), sin(dir), frandom(-0.35, 0.1));
		a.A_SprayDecal((big ? "VGBigSplat" : "VGSplat") .. VGBlood.FamLetter(fam), big ? 192 : 128, (0, 0, at.z - a.Pos.z), d.Unit());
	}

	void CeilingSplat(Actor a, int fam)
	{
		FLineTraceData t;
		if (!a.LineTrace(0, 320, -90, TRF_THRUACTORS | TRF_THRUHITSCAN, a.Height * 0.8, 0, 0, t)) return;
		if (t.HitType != TRACE_HitCeiling || t.HitSector.GetTexture(Sector.ceiling) == skyflatnum) return;
		if (t.HitSector.ceilingplane.Normal.z > -0.99) return;
		Vector2 p = t.HitLocation.xy + (frandom(-16, 16), frandom(-16, 16));
		let s = VGCeilSplat(Actor.Spawn("VGCeilSplat", (p, t.HitSector.ceilingplane.ZatPoint(p) - 0.05)));
		if (!s) return;
		s.Init(fam);
		Keep(ceils, s, 'vg_splats_max');
	}

	void SpawnChunks(Actor a, int n, int fam, double away, bool directed)
	{
		for (int i = 0; i < n; i++)
		{
			let c = VGChunk(Actor.Spawn("VGChunk", a.Pos + (frandom(-0.5, 0.5) * a.Radius, frandom(-0.5, 0.5) * a.Radius, a.Height * frandom(0.25, 0.85))));
			if (!c) continue;
			c.Init(fam);
			double ang = directed ? away + frandom(-70, 70) : frandom(0, 360), s = frandom(3, 9);
			c.Vel = (cos(ang) * s, sin(ang) * s, frandom(4, 11));
			Keep(chunks, c, 'vg_gibs_max');
		}
	}

	void ScreenBlood(Actor a, double radius, int count)
	{
		for (int pn = 0; pn < MAXPLAYERS; pn++)
		{
			if (!playeringame[pn] || !players[pn].mo) continue;
			double d = players[pn].mo.Distance3D(a);
			if (d > radius) continue;
			int n = int(count * (1 - d / radius)) + 1;
			for (int i = 0; i < n; i++)
			{
				scrTime.Push(level.time); scrPlayer.Push(pn); scrFam.Push(VGBlood.Family(a));
				scrX.Push(frandom(0.05, 0.95)); scrY.Push(frandom(0.05, 0.8)); scrSize.Push(frandom(0.6, 1.4));
				scrTex.Push(random(0, 3));
			}
		}
	}

	static bool Bleeds(Actor a) { return a && !a.bNoBlood && !a.bInvulnerable && !a.bDormant && (a.bIsMonster || a.player); }

	// ------------------------------------------------ events
	override void WorldThingDamaged(WorldEvent e)
	{
		let a = e.Thing;
		double k = VGBlood.Amount();
		if (k <= 0 || !Bleeds(a) || e.Damage <= 0) return;
		int fam = VGBlood.Family(a);
		Actor from = e.Inflictor ? e.Inflictor : e.DamageSource;
		bool blast = e.DamageType == 'Explosive' || (e.DamageFlags & DMG_EXPLOSION);
		Vector3 at = (e.Inflictor && e.Inflictor != e.DamageSource && !blast) ? e.Inflictor.Pos : a.Pos + (0, 0, a.Height * frandom(0.45, 0.8));
		at.z = clamp(at.z, a.Pos.z + 2, a.Pos.z + a.Height);
		double dir = from && from != a ? from.AngleTo(a) : a.Angle + 180;

		Drops(a, at, dir, int((3 + min(e.Damage, 50) / 6) * k), fam);
		if (random() < 140 * k) WallSplat(a, at, dir + frandom(-15, 15), fam, e.Damage >= 40 || blast);
		if ((e.Damage >= 25 || blast) && random() < 80 * k) CeilingSplat(a, fam);
		if (a.health > 0 && a.health < a.GetSpawnHealth() * 0.6 && bleeders.Find(a) == bleeders.Size()) bleeders.Push(a);
	}

	override void WorldThingDied(WorldEvent e)
	{
		let a = e.Thing;
		lastDied = a; lastDiedTic = level.time;
		double k = VGBlood.Amount();
		if (k <= 0 || !Bleeds(a)) return;
		int fam = VGBlood.Family(a);
		Actor from = e.Inflictor ? e.Inflictor : a.target;
		bool gib = a.health < a.GetGibHealth() && a.FindState("XDeath");
		bool voxel = (a.GetClassName() .. "").Left(5) == "Voxel";
		double away = from && from != a ? from.AngleTo(a) : a.Angle + 180;

		// the voxel bodies fall away from the shooter: put the pool where the body lands
		Vector2 at = a.Pos.xy + (voxel ? Actor.AngleToVector(away) * a.Height * 0.4 : (0, 0));
		string size = a.Radius <= 22 ? "m" : a.Radius <= 40 ? "l" : "h";
		SpawnPool(at, fam, size, 0, 7, a.Radius <= 22 ? 18 : 24);

		if (gib)
		{
			for (int i = 0; i < 3 * k; i++)
				SpawnPool(a.Pos.xy + Actor.AngleToVector(frandom(0, 360)) * frandom(20, 60), fam, "s", 2, random(4, 7), random(5, 30));
			for (int i = 0; i < 4 * k; i++) WallSplat(a, a.Pos + (0, 0, a.Height * 0.6), frandom(0, 360), fam, true);
			if (random() < 200 * k) CeilingSplat(a, fam);
			Drops(a, a.Pos + (0, 0, a.Height * 0.6), 0, int(30 * k), fam, 180, 7);
			// the voxel enemies throw their own VGGib chunks, which become VGChunk models in WorldTick
			if (!voxel) SpawnChunks(a, int((6 + a.Radius / 4) * k / 1.5), fam, away, from != null);
			ScreenBlood(a, 160, 6);
		}
		else if (e.DamageType == 'Explosive')
			ScreenBlood(a, 110, 3);
		int bi = bleeders.Find(a); if (bi < bleeders.Size()) bleeders.Delete(bi);
	}

	override void WorldThingSpawned(WorldEvent e)
	{
		// the main mod's flying gib particles: swap them for persistent voxel chunks once their velocity is set
		if (e.Thing && e.Thing.GetClassName() == 'VGGib')
		{
			pendingGibs.Push(e.Thing);
			pendingOwners.Push(lastDiedTic == level.time ? lastDied : null);
		}
	}

	override void WorldTick()
	{
		for (int i = 0; i < pendingGibs.Size(); i++)
		{
			let g = pendingGibs[i];
			if (!g) continue;
			if (VGBlood.Amount() > 0)
			{
				let c = VGChunk(Actor.Spawn("VGChunk", g.Pos));
				if (c)
				{
					c.Init(pendingOwners[i] ? VGBlood.Family(pendingOwners[i]) : VGF_RED);
					c.Vel = g.Vel;
					Keep(chunks, c, 'vg_gibs_max');
				}
				g.Destroy();
			}
		}
		pendingGibs.Clear(); pendingOwners.Clear();

		// wounded monsters leave a trail
		double k = VGBlood.Amount();
		for (int i = bleeders.Size() - 1; i >= 0; i--)
		{
			let a = bleeders[i];
			if (!a || a.health <= 0 || a.health >= a.GetSpawnHealth() * 0.6) { bleeders.Delete(i); continue; }
			int every = int(6 + 14 * a.health / (a.GetSpawnHealth() * 0.6));
			if (k > 0 && (level.time + i * 3) % every == 0)
			{
				Vector3 at = a.Pos + (frandom(-0.4, 0.4) * a.Radius, frandom(-0.4, 0.4) * a.Radius, a.Height * frandom(0.35, 0.75));
				Drops(a, at, frandom(0, 360), int(1 + k), VGBlood.Family(a), 180, 1);
			}
		}

		// forget old screen drops
		while (scrTime.Size() && level.time - scrTime[0] > 70)
		{
			scrTime.Delete(0); scrX.Delete(0); scrY.Delete(0); scrSize.Delete(0); scrTex.Delete(0); scrFam.Delete(0); scrPlayer.Delete(0);
		}
	}

	override void RenderOverlay(RenderEvent e)
	{
		if (!scrTime.Size() || !CVar.GetCVar('vg_screenblood', players[consoleplayer]).GetBool()) return;
		double w = Screen.GetWidth(), h = Screen.GetHeight();
		for (int i = 0; i < scrTime.Size(); i++)
		{
			if (scrPlayer[i] != consoleplayer) continue;
			double t = (level.time - scrTime[i] + e.FracTic) / 70.0;
			if (t < 0 || t > 1) continue;
			let tex = TexMan.CheckForTexture("VGSCR" .. VGBlood.FamLetter(scrFam[i]) .. scrTex[i], TexMan.Type_Any);
			if (!tex.IsValid()) continue;
			Vector2 sz = TexMan.GetScaledSize(tex);
			double s = scrSize[i] * h / 400;
			Screen.DrawTexture(tex, false, scrX[i] * w, scrY[i] * h + t * t * h * 0.08,
				DTA_DestWidthF, sz.x * s, DTA_DestHeightF, sz.y * s, DTA_Alpha, 0.85 * (1 - t * t), DTA_CenterOffset, true);
		}
	}
}
