DO
$BODY$
DECLARE
	guns jsonb := '{"AK74N": 77000, "Kriss Vector Gen II": 30000, "SCAR-L CQC": 2500, "VSS Vintorez": 40000, "M4A1 Carbine": 0, "AK5C": 0}';
	attachments jsonb := '{"AK74N CAA Rail": 900, "M4 Long Barrel": 1500, "RIS Barrel": 4500, "AFG2 Angled Grip": 450, "MOE Vertical Grip": 1700, "Tango Stubby Grip":650, "Scorpion Handle": 4850, "Extended Magazine": 3000, "Compensator": 750, "Flash Hider": 300, "Muzzle Brake": 1750, "Osprey Suppressor": 750, "RUS PBS4": 350, "Suppressor": 550, "EOTECH Holographic Sight": 500, "RUS OKP7 Sight": 120, "SCAR-L Iron Sight II": 120, "SM REFLEX Sight": 120, "TRIJC ACOG Sight": 1500, "Wolf PSO-1": 1250, "M7A1 Stock": 3700, "MOE Stock": 150}';
	gun record;
	attachment record;
	cur cursor for select * from os_players;
	r os_players%rowtype;
	inc integer;
BEGIN
	FOR r in cur LOOP
		inc := 0;
		FOR gun IN SELECT * FROM jsonb_each_text(guns) LOOP
			if r.gears -> gun.key ->> 'owned' = 'true' then
				inc := inc + gun.value::integer;
				for attachment in select * from jsonb_each_text(attachments) loop
					if r.gears -> gun.key -> 'ownedAttcs' ->> attachment.key = 'true' then
						inc := inc + attachment.value::integer;
					end if;
				end loop;
			end if;
		END LOOP;
		IF inc > 0 then
			raise notice 'refund $% to %', inc, r.user_name;
		end if;
		update os_players set money = money + inc where current of cur;
	end loop;
END;
$BODY$;


DELETE FROM os_players a USING (
  SELECT MIN(ctid) as ctid, user_id
    FROM os_players 
    GROUP BY user_id HAVING COUNT(*) > 1
  ) b
  WHERE a.user_id = b.user_id 
  AND a.ctid <> b.ctid


CREATE UNIQUE INDEX CONCURRENTLY equipment_equip_id 
ON equipment (equip_id);

ALTER TABLE equipment 
ADD CONSTRAINT unique_equip_id 
UNIQUE USING INDEX equipment_equip_id;

update os_players 