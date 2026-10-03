#if defined _crxknives_included
	#endinput
#endif
#define _crxknives_included

native crxknives_get_knives_num();
native crxknives_get_attribute_str(knife, const attribute[], value[], valueLen, bool:localize = false);
native crxknives_get_attribute_int(knife, const attribute[], &value, bool:localize = false);
native crxknives_select_knife(id, knife);
native crxknives_get_user_knife(id);

forward crxknives_attempt_change(id, knife);
forward crxknives_knife_updated(id, knife, bool:onconnect);