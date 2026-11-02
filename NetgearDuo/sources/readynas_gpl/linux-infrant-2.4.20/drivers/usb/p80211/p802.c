#define WLAN_HOSTIF WLAN_USB
#define __LINUX_WLAN__
#define CONFIG_NETLINK 1
#define CONFIG_PACKET 1
#define WIRELESS_EXT 1
#include "p80211frm.c"
#include "p80211netdev.c"
#include "p80211wep.c"
#include "p80211conv.c"
#include "p80211mod.c"
#include "p80211req.c"
#include "p80211wext.c"
