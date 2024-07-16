########################################################################
#
#                      CONFIG_BLUETOOTH_MODULES
#
#Changing this configuration item is not recommended!
########################################################################
CONFIG_BLUETOOTH_MODULES ?= multibt


########################################################################
#
#                      CONFIG_WIFI_MODULES
#
#List of current supported:
#ap6181 ap6335 ap6234 ap6255 ap6271 ap6212 ap6354 ap6356 ap6398s ap6275s bcm43751_s bcm43458_s bcm4358_s
#ap6269 ap62x8 ap6275p ap6275hh3 qca6174 w1 rtl8723du rtl8723bu rtl8821cu rtl8822cu rtl8822cs sd8987 mt7661
#mt7668u
#
#You can get the latest supported list by executing the make command:
#cd vendor/amlogic/common/wifi_bt/wifi/tools && make get_modules
########################################################################
CONFIG_WIFI_MODULES ?= rtl8821cu ap6398s rtl8822cu

########################################################################
#
#                      CONFIG_BCMDHD_CUSB
#
#For BCM single interface USB WiFi,the value is 'y' or 'n'
########################################################################
CONFIG_BCMDHD_CUSB ?= n


########################################################################
#
#                      Load customer's config
#
########################################################################
$(warning loading customer's wifi and bt config: $(CUSTOMER_WIFIBT_CONFIG))
-include $(CUSTOMER_WIFIBT_CONFIG)
########################################################################

