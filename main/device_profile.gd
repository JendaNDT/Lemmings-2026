class_name DeviceProfile
extends RefCounted
## Stejná hra; odlišnosti mobilního ovládání a grafické kvality jsou pouze zde.


static func touch_mode() -> bool:
	return OS.has_feature("android") or "--mobile-preview" in OS.get_cmdline_user_args()
