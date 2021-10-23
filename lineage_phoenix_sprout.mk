# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit some common Lineage stuff
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

# Inherit from phoenix_sprout device
$(call inherit-product, $(LOCAL_PATH)/device.mk)

PRODUCT_BRAND := lge
PRODUCT_DEVICE := phoenix_sprout
PRODUCT_MANUFACTURER := lge
PRODUCT_NAME := lineage_phoenix_sprout
PRODUCT_MODEL := LM-Q910

PRODUCT_GMS_CLIENTID_BASE := android-lge
TARGET_VENDOR := lge
TARGET_VENDOR_PRODUCT_NAME := phoenix_sprout
PRODUCT_BUILD_PROP_OVERRIDES += PRIVATE_BUILD_DESC="phoenix_lao_com-user 11 RKQ1.201123.002 211181009fda7 release-keys"

# Set BUILD_FINGERPRINT variable to be picked up by both system and vendor build.prop
BUILD_FINGERPRINT := lge/phoenix_lao_com/phoenix_sprout:11/RKQ1.201123.002/211181009fda7:user/release-keys
