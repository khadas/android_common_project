define root-dir
$(strip \
 $(shell bash -c "\
 while [[ ( ! ( -f build/gki/README.md ) ) && ( \`pwd\` != "/" ) ]]; do\
  cd ..;\
 done;\
 if [[ -f \`pwd\`/build/gki/README.md ]]; then\
  echo \`pwd\`;\
 else\
  echo "";\
 fi"\
 )\
)
endef

define cur-dir
$(strip \
  $(eval LOCAL_MODULE_MAKEFILE := $$(lastword $$(MAKEFILE_LIST))) \
  $(shell cd $(patsubst %/,%,$(dir $(LOCAL_MODULE_MAKEFILE))) && pwd) \
)
endef

CUSTOMER_WIFIBT_CONFIG ?= $(if $(PRODUCT_DIRNAME),$(call root-dir)/$(PRODUCT_DIRNAME)/wifibt.build.config.customer.mk,$(call cur-dir)/wifibt.build.config.customer.mk)

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
CONFIG_WIFI_MODULES ?= rtl8723du rtl8723bu ap62x8

#If environment variable 'MULTI_WIFI' is not set to 'false',then ignore the above 'CONFIG_WIFI_MODULES' and compile all currently supported WiFi
ifneq ($(MULTI_WIFI),false)
CONFIG_WIFI_MODULES := multiwifi
endif


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

