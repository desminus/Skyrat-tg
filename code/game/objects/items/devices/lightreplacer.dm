
// Light Replacer (LR)
//
// ABOUT THE DEVICE
//
// This is a device supposedly to be used by Janitors and Janitor Cyborgs which will
// allow them to easily replace lights. This was mostly designed for Janitor Cyborgs since
// they don't have hands or a way to replace lightbulbs.
//
// HOW IT WORKS
//
// You attack a light fixture with it, if the light fixture is broken it will replace the
// light fixture with a working light; the broken light is then placed on the floor for the
// user to then pickup with a trash bag. If it's empty then it will just place a light in the fixture.
//
// HOW TO REFILL THE DEVICE
//
// It will need to be manually refilled with lights.
// If it's part of a robot module, it will charge when the Robot is inside a Recharge Station.
//
// EMAGGED FEATURES
//
// I'm not sure everyone will react the emag's features so please say what your opinions are of it. (I'm pretty sure the players like it)
//
// When emagged it will rig every light it replaces with plasma, which will slowly heat up and ignite while the light is on.
// This is VERY noticable, even the device's name changes when you emag it so if anyone
// examines you when you're holding it in your hand, you will be discovered.
//

#define GLASS_SHEET_USES 5
#define LIGHTBULB_COST 1
#define BULB_SHARDS_REQUIRED 4

/obj/item/lightreplacer
	name = "light replacer"
	desc = "A device to automatically replace lights. Refill with broken or working light bulbs, or sheets of glass."
	icon = 'icons/obj/janitor.dmi'
	icon_state = "lightreplacer"
	inhand_icon_state = "electronic"
	worn_icon_state = "light_replacer"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	flags_1 = CONDUCT_1
	slot_flags = ITEM_SLOT_BELT
	force = 8

	/// How many uses does our light replacer have?
	var/uses = 10
	/// The maximum number of lights this replacer can hold
	var/max_uses = 20
	/// The light replacer's charge increment (used for adding to cyborg light replacers)
	var/charge = 1

	/// Eating used bulbs gives us bulb shards. Requires BULB_SHARDS_MAXIMUM to produce a new light.
	var/bulb_shards = 0

	/// whether it is "bluespace powered" (can be used at a range)
	var/bluespace_toggle = FALSE

/obj/item/lightreplacer/examine(mob/user)
	. = ..()
	. += status_string()

/obj/item/lightreplacer/pre_attack(atom/target, mob/living/user, params)
	. = ..()
	if(.)
		return
	return do_action(target, user) //if we are attacking a valid target[light, floodlight or turf] stop here

/obj/item/lightreplacer/attackby(obj/item/insert, mob/user, params)
	. = ..()

	if(istype(insert, /obj/item/stack/sheet/glass))
		var/obj/item/stack/sheet/glass/glass_to_insert = insert
		if(uses >= max_uses)
			to_chat(user, span_warning("[src.name] is full."))
			return TRUE
		else if(glass_to_insert.use(LIGHTBULB_COST))
			add_uses(GLASS_SHEET_USES)
			to_chat(user, span_notice("You insert a piece of glass into \the [src.name]. You have [uses] light\s remaining."))
			return TRUE
		else
			to_chat(user, span_warning("You need one sheet of glass to replace lights!"))

	if(istype(insert, /obj/item/shard))
		if(uses >= max_uses)
			to_chat(user, span_warning("\The [src] is full."))
			return TRUE
		if(!user.temporarilyRemoveItemFromInventory(insert))
			return TRUE
		add_uses(round(GLASS_SHEET_USES*0.75))
		to_chat(user, span_notice("You insert a shard of glass into \the [src]. You have [uses] light\s remaining."))
		qdel(insert)
		return TRUE

	if(istype(insert, /obj/item/light))
		var/obj/item/light/light_to_insert = insert
		if(light_to_insert.status == 0) // LIGHT OKAY
			if(uses < max_uses)
				if(!user.temporarilyRemoveItemFromInventory(insert))
					return TRUE
				add_uses(1)
				qdel(light_to_insert)
		else
			if(!user.temporarilyRemoveItemFromInventory(insert))
				return TRUE
			to_chat(user, span_notice("You insert [light_to_insert] into \the [src]."))
			add_shards(1, user)
			qdel(light_to_insert)
		return TRUE

	if(istype(insert, /obj/item/storage))
		var/obj/item/storage/storage_to_empty = insert
		var/found_lightbulbs = FALSE
		var/replaced_something = TRUE

		for(var/obj/item/item_to_check in storage_to_empty.contents)
			if(!istype(item_to_check, /obj/item/light))
				continue
			var/obj/item/light/found_light = item_to_check
			found_lightbulbs = TRUE
			if(src.uses >= max_uses)
				break
			if(found_light.status == LIGHT_OK)
				replaced_something = TRUE
				add_uses(1)
				qdel(found_light)

			else if(found_light.status == LIGHT_BROKEN || found_light.status == LIGHT_BURNED)
				replaced_something = TRUE
				add_shards(1, user)
				qdel(found_light)

		if(!found_lightbulbs)
			to_chat(user, span_warning("\The [storage_to_empty] contains no bulbs."))
			return TRUE

		if(!replaced_something && src.uses == max_uses)
			to_chat(user, span_warning("\The [src] is full!"))
			return TRUE

		to_chat(user, span_notice("You fill \the [src] with lights from \the [storage_to_empty]. " + status_string() + ""))
		return TRUE


/obj/item/lightreplacer/emag_act()
	if(obj_flags & EMAGGED)
		return
	obj_flags |= EMAGGED
	playsound(loc, SFX_SPARKS, 100, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)
	update_appearance()

/obj/item/lightreplacer/update_name(updates)
	. = ..()
	name = (obj_flags & EMAGGED) ? "shortcircuited [initial(name)]" : initial(name)

/obj/item/lightreplacer/update_icon_state()
	icon_state = "[initial(icon_state)][(obj_flags & EMAGGED ? "-emagged" : "")]"
	return ..()

/obj/item/lightreplacer/vv_edit_var(vname, vval)
	if(vname == NAMEOF(src, obj_flags))
		update_appearance()
	return ..()


/obj/item/lightreplacer/attack_self(mob/user)
	for(var/obj/machinery/light/target in user.loc)
		replace_light(target, user)
	to_chat(user, status_string())


/**
 * attempts to fix lights, flood lights & lights on a turf
 * Arguments
 * * target - the target we are trying to fix
 * * user - the mob performing this action
 * returns TRUE if the target was valid[light, floodlight or turf] regardless if any light's were fixed or not
 */
/obj/item/lightreplacer/proc/do_action(atom/target, mob/user)
	// if we are attacking an light fixture then replace it directly
	if(istype(target, /obj/machinery/light))
		if(replace_light(target, user) && bluespace_toggle)
			user.Beam(target, icon_state = "rped_upgrade", time = 1 SECONDS)
			playsound(src, 'sound/items/pshoom.ogg', 40, 1)
		return TRUE

	// if we are attacking a floodlight frame finish it
	if(istype(target, /obj/structure/floodlight_frame))
		var/obj/structure/floodlight_frame/frame = target
		if(frame.state == FLOODLIGHT_NEEDS_LIGHTS && Use(user))
			new /obj/machinery/power/floodlight(frame.loc)
			if(bluespace_toggle)
				user.Beam(target, icon_state = "rped_upgrade", time = 1 SECONDS)
				playsound(src, 'sound/items/pshoom.ogg', 40, 1)
			to_chat(user, span_notice("You finish \the [frame] with a light tube."))
			qdel(frame)
		return TRUE

	//attempt to replace all light sources on the turf
	if(isturf(target))
		var/light_replaced = FALSE
		for(var/atom/target_atom in target)
			if(replace_light(target_atom, user))
				light_replaced = TRUE
		if(light_replaced && bluespace_toggle)
			user.Beam(target, icon_state = "rped_upgrade", time = 1 SECONDS)
			playsound(src, 'sound/items/pshoom.ogg', 40, 1)
		return TRUE

	return FALSE

/obj/item/lightreplacer/afterattack(atom/target, mob/user, proximity)
	. = ..()

	// has no bluespace capabilities
	if(!bluespace_toggle)
		return
	// target not in range
	if(target.z != user.z)
		return
	// target not in view
	if(!(target in view(7, get_turf(user))))
		to_chat(user, span_warning("The \'Out of Range\' light on [src] blinks red."))
		return

	//replace lights & stuff
	do_action(target, user)

/obj/item/lightreplacer/proc/status_string()
	return "It has [uses] light\s remaining (plus [bulb_shards] fragment\s)."

/obj/item/lightreplacer/proc/Use(mob/user)
	if(uses <= 0)
		return FALSE

	playsound(src.loc, 'sound/machines/click.ogg', 50, TRUE)
	src.add_fingerprint(user)
	add_uses(-1)

	return TRUE

// Negative numbers will subtract
/obj/item/lightreplacer/proc/add_uses(amount = 1)
	uses = clamp(uses + amount, 0, max_uses)

/obj/item/lightreplacer/proc/add_shards(amount = 1, user)
	bulb_shards += amount
	var/new_bulbs = round(bulb_shards / BULB_SHARDS_REQUIRED)
	if(new_bulbs > 0)
		add_uses(new_bulbs)
	bulb_shards = bulb_shards % BULB_SHARDS_REQUIRED
	if(new_bulbs != 0)
		to_chat(user, span_notice("\The [src] fabricates a new bulb from the broken glass it has stored. It now has [uses] uses."))
		playsound(src.loc, 'sound/machines/ding.ogg', 50, TRUE)
	return new_bulbs

/obj/item/lightreplacer/proc/Charge(mob/user)
	charge += 1
	if(charge > 3)
		add_uses(1)
		charge = 1

/obj/item/lightreplacer/proc/replace_light(obj/machinery/light/target, mob/living/user)
	//Confirm that it's a light we're testing, because afterattack runs this for everything on a given turf and will runtime
	if(!istype(target))
		return FALSE
	//If the light source is ok then what are we doing here
	if(target.status == LIGHT_OK)
		to_chat(user, span_warning("There is a working [target.fitting] already inserted!"))
		return FALSE
	//Were all out
	if(!Use(user))
		to_chat(user, span_warning("\The [src]'s refill light blinks red."))
		return FALSE

	//remove any broken light on the fixture & add it as a shard
	if(target.status != LIGHT_EMPTY)
		add_shards(1, user)
		target.status = LIGHT_EMPTY
		target.update()
	//create a copy of the light type & copy it's params onto the target
	var/obj/item/light/old_light = new target.light_type()
	target.status = old_light.status
	target.switchcount = old_light.switchcount
	target.brightness = old_light.brightness
	if(obj_flags & EMAGGED)
		target.create_reagents(LIGHT_REAGENT_CAPACITY, SEALED_CONTAINER | TRANSPARENT)
		target.reagents.add_reagent(/datum/reagent/toxin/plasma, 10)
	target.on = target.has_power()
	target.update()
	//clean up
	qdel(old_light)
	to_chat(user, span_notice("You replace \the [target.fitting] with \the [src]."))

	return TRUE

/obj/item/lightreplacer/cyborg/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NODROP, CYBORG_ITEM_TRAIT)

/obj/item/lightreplacer/blue
	name = "bluespace light replacer"
	desc = "A modified light replacer that zaps lights into place. Refill with broken or working lightbulbs, or sheets of glass."
	icon_state = "lightreplacer_blue"
	bluespace_toggle = TRUE

/obj/item/lightreplacer/blue/emag_act()
	return  // balancing against longrange explosions

#undef GLASS_SHEET_USES
#undef LIGHTBULB_COST
#undef BULB_SHARDS_REQUIRED
