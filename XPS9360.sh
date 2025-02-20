#!/bin/sh

# Bold / Non-bold
BOLD="\033[1m"
RED="\033[0;31m"
GREEN="\033[0;32m"
BLUE="\033[1;34m"
#echo -e "\033[0;32mCOLOR_GREEN\t\033[1;32mCOLOR_LIGHT_GREEN"
OFF="\033[m"

# Repository location
REPO=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
GIT_DIR="${REPO}"

git_update()
{
	cd ${REPO}
	echo "${GREEN}[GIT]${OFF}: Updating local data to latest version"

	echo "${BLUE}[GIT]${OFF}: Updating to latest Dell-XPS0-9360-Hackintosh git master"
	echo "${BLUE}[GIT]${OFF}: Git clone newest repository to current path"
	git clone https://github.com/the-Quert/Dell-XPS-9360-Hackintosh.git
}

compile_dsdt()
{
	echo "${GREEN}[DSDT]${OFF}: Compiling  DSDT / SSDT hotpatches in ./DSDT"
	cd "${REPO}"

	for f in ./DSDT/*.dsl
	do
		echo "${BLUE}$(basename $f)${OFF}: Compiling to ./CLOVER/ACPI/patched"
		./tools/iasl -vr -w1 -ve -p ./CLOVER/ACPI/patched/$(basename -s .dsl $f).aml $f
	done
}

patch_hda()
{
	echo "${GREEN}[HDA]${OFF}: Creating AppleHDA injection kernel extension for ${BOLD}ALC256${OFF}"
	cd "${REPO}"

	plist=./audio/AppleHDA_ALC256.kext/Contents/Info.plist

	echo "       --> ${BOLD}Creating AppleHDA_ALC256 file layout${OFF}"
	rm -R ./audio/AppleHDA_ALC256.kext 2&>/dev/null

	cp -RX /System/Library/Extensions/AppleHDA.kext ./audio/AppleHDA_ALC256.kext
	rm -R ./audio/AppleHDA_ALC256.kext/Contents/Resources/*
	rm -R ./audio/AppleHDA_ALC256.kext/Contents/PlugIns
	rm -R ./audio/AppleHDA_ALC256.kext/Contents/_CodeSignature
	rm ./audio/AppleHDA_ALC256.kext/Contents/version.plist

	echo "       --> ${BOLD}Patching AppleHDA_ALC256 executable${OFF}"
	perl -i -pe 's|\x61\x02\xEC\x10|\x00\x00\x00\x00|s' ./audio/AppleHDA_ALC256.kext/Contents/MacOS/AppleHDA
	perl -i -pe 's|\x62\x02\xEC\x10|\x00\x00\x00\x00|s' ./audio/AppleHDA_ALC256.kext/Contents/MacOS/AppleHDA
	perl -i -pe 's|\x85\x08\xEC\x10|\x00\x00\x00\x00|s' ./audio/AppleHDA_ALC256.kext/Contents/MacOS/AppleHDA
	perl -i -pe 's|\x84\x19\xD4\x11|\x56\x02\xEC\x10|s' ./audio/AppleHDA_ALC256.kext/Contents/MacOS/AppleHDA

	echo "       --> ${BOLD}Copying AppleHDA_ALC256 audio platform & layouts${OFF}"

	cp audio/Platforms.plist ./audio/AppleHDA_ALC256.kext/Contents/Resources/Platforms.xml
	./tools/zlib ./audio/AppleHDA_ALC256.kext/Contents/Resources/Platforms.xml
	rm ./audio/AppleHDA_ALC256.kext/Contents/Resources/Platforms.xml

    layouts=`ls audio/layout*.plist`
    for layout in $layouts; do
        layout=`basename $layout`
        cp audio/$layout ./audio/AppleHDA_ALC256.kext/Contents/Resources/${layout/.plist/.xml}
		./tools/zlib ./audio/AppleHDA_ALC256.kext/Contents/Resources/${layout/.plist/.xml}
		rm ./audio/AppleHDA_ALC256.kext/Contents/Resources/${layout/.plist/.xml}
    done

	echo "       --> ${BOLD}Configuring AppleHDA_ALC256 Info.plist${OFF}"
	replace=`/usr/libexec/PlistBuddy -c "Print :NSHumanReadableCopyright" $plist | perl -Xpi -e 's/(\d*\.\d*)/9\1/'`
	/usr/libexec/PlistBuddy -c "Set :NSHumanReadableCopyright '$replace'" $plist
	replace=`/usr/libexec/PlistBuddy -c "Print :CFBundleGetInfoString" $plist | perl -Xpi -e 's/(\d*\.\d*)/9\1/'`
	/usr/libexec/PlistBuddy -c "Set :CFBundleGetInfoString '$replace'" $plist
	replace=`/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" $plist | perl -Xpi -e 's/(\d*\.\d*)/9\1/'`
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion '$replace'" $plist
	replace=`/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" $plist | perl -Xpi -e 's/(\d*\.\d*)/9\1/'`
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString '$replace'" $plist
	/usr/libexec/PlistBuddy -c "Add ':HardwareConfigDriver_Temp' dict" $plist
	/usr/libexec/PlistBuddy -c "Merge /System/Library/Extensions/AppleHDA.kext/Contents/PlugIns/AppleHDAHardwareConfigDriver.kext/Contents/Info.plist ':HardwareConfigDriver_Temp'" $plist
	/usr/libexec/PlistBuddy -c "Copy ':HardwareConfigDriver_Temp:IOKitPersonalities:HDA Hardware Config Resource' ':IOKitPersonalities:HDA Hardware Config Resource'" $plist
	/usr/libexec/PlistBuddy -c "Delete ':HardwareConfigDriver_Temp'" $plist
	/usr/libexec/PlistBuddy -c "Delete ':IOKitPersonalities:HDA Hardware Config Resource:HDAConfigDefault'" $plist
	/usr/libexec/PlistBuddy -c "Delete ':IOKitPersonalities:HDA Hardware Config Resource:PostConstructionInitialization'" $plist
	/usr/libexec/PlistBuddy -c "Add ':IOKitPersonalities:HDA Hardware Config Resource:IOProbeScore' integer" $plist
	/usr/libexec/PlistBuddy -c "Set ':IOKitPersonalities:HDA Hardware Config Resource:IOProbeScore' 2000" $plist
	/usr/libexec/PlistBuddy -c "Merge ./audio/ahhcd.plist ':IOKitPersonalities:HDA Hardware Config Resource'" $plist

	echo "       --> ${BOLD}Created AppleHDA_ALC256.kext${OFF}"
	sudo cp -r ./audio/AppleHDA_ALC256.kext /Library/Extensions
	echo "       --> ${BOLD}Installed AppleHDA_ALC256.kext to /Library/Extensions${OFF}"
	sudo cp -r ./kexts/Library-Extensions/CodecCommander.kext /Library/Extensions
	echo "       --> ${BOLD}Installed CodecCommander.kext to /Library/Extensions${OFF}"
}

combo_jack()
{
	echo "${GREEN}[ComboJack]${OFF}: Installing ComboJack for ${BOLD}ALC256${OFF}"
	./ComboJack/install.sh
}

enable_trim()
{
	echo "${GREEN}[TRIM]${OFF}: Enabling ${BOLD}TRIM${OFF} support for 3rd party SSD"
	sudo trimforce enable
}

enable_3rdparty()
{
	echo "${GREEN}[3rd Party]${OFF}: Enabling ${BOLD}3rd Party${OFF} application support"
	sudo spctl --master-disable
}

disable_touchid()
{
	echo "${GREEN}[TouchID]${OFF}: disabling ${BOLD}TouchID${OFF} launch daemons"
	sudo rm /System/Library/LaunchDaemons/com.apple.biometrickitd.plist
	sudo rm /System/Library/LaunchDaemons/com.apple.biokitaggdd.plist
}

RETVAL=1

case "$1" in
	--update)
		git_pull
		RETVAL=0
		;;
	--compile-dsdt)
		compile_dsdt
		RETVAL=0
		;;
	--combo-jack)
		combo_jack
		RETVAL=0
		;;
	--enable-trim)
		enable_trim
		RETVAL=0
		;;
	--enable-3rdparty)
		enable_3rdparty
		RETVAL=0
		;;
	--disable-touchid)
		disable_touchid
		RETVAL=0
		;;
	*)
		echo "${BOLD}Dell XPS 9360 Hackintosh${OFF} - Mojave 10.14.6 (18G84)"
		echo "https://github.com/the-Quert/Dell-XPS-9360-Hackintosh"
		echo
		echo "\t${BOLD}--update${OFF}: Update to latest git version (including externals)"
		echo "\t${BOLD}--compile-dsdt${OFF}: Compile DSDT files to ./DSDT/compiled"
		echo "\t${BOLD}--combo-jack${OFF}: Install ComboJack user daemon (Headset / Headphone detection)"
		echo "\t${BOLD}--enable-trim${OFF}: Enable trim support for 3rd party SSD"
		echo "\t${BOLD}--enable-3rdparty${OFF}: Enable 3rd party application support (run app from anywhere)"
		echo "\t${BOLD}--disable-touchid${OFF}: Disable Touch ID daemons (Used for Macbook15,2 profile)"
		echo
		echo "Credits:"
		echo "${BLUE}ComboJack${OFF}: https://github.com/hackintosh-stuff/ComboJack"
		echo "${BLUE}CPUFriend${OFF}: https://github.com/acidanthera/CPUFriend"
		echo "${BLUE}HiDPI${OFF}: https://github.com/xzhih/one-key-hidpi"
		echo "${BLUE}OpenCore-Configurator${OFF}: https://github.com/notiflux/OpenCore-Configurator"
		echo "${BLUE}Leo Neo Usfsg${OFF}: https://www.facebook.com/yuting.lee.leo"
		echo
		;;
esac

exit $RETVAL
