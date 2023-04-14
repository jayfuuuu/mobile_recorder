# Init
Init() {
	local platform=$1
	Exist $platform
	case $platform in
	"android")
		# 判斷 Android 版本是否 < 7
		AndroidVersionOver7
		# 設定本次 Process 資料夾路徑
		CreateFolder "AndroidRecorder"
		;;
	"ios")
		target_device=$(idb list-targets | grep ooted | cut -d '|' -f 2)
		CreateFolder "iOSRecorder"
		;;
	esac
}
# Init sub-function
Exist() {
	local platform=$1
	case $platform in
	"android")
		target_device=$(adb devices | tr "\n" ':' | cut -d ':' -f 2)
		;;
	"ios")
		target_device=$(idb list-targets | grep ooted | cut -d '|' -f 1,2,5)
		;;
	esac

	if [[ $target_device ]]; then
		echo "\033[1;34m目前所連接的裝置為:\033[0m"
		echo "\033[1;35m$target_device\033[0m"
	else
		echo "\033[0;31mx ERROR: NO CONNECT/BOOT ANY $target_device DEVICE\033[0m"
		TearDown
	fi
}
# Init sub-function
AndroidVersionOver7() {
	androidOsVersion=$(adb shell getprop ro.build.version.release | cut -f1 -d .)
	androidVersionOver7=1
	minVersion=7
	if [[ $androidOsVersion -lt $minVersion ]]; then
		androidVersionOver7=0
	fi
}
# Init sub-function
CreateFolder() {
	local platform=$1
	basePath="/Users/$(whoami)/Desktop/$platform"
	folderName=$(date +"%Y%m%d_%H%M%S")
	if [[ -d $basePath ]]; then
		mkdir $basePath/$folderName
	else
		mkdir $basePath
		mkdir $basePath/$folderName
	fi
}
# Start
MainProcess() {
	echo "\033[1;34mStart Record Screen & Log or ScreenShot:\033[0m"
	read -p "Videorecord: v,  Screenshot: s, change platform: r > " process
	case $process in
	"v")
		case $platform in 
		"android")
			read -p "please enter package name for filter log , or not to enter > " package
			Recorder $package
			;;
		"ios")
			Recorder
			;;
		esac
		;;
	"s")
		Screenshot
		;;
	"r")
		read -p "Android: 1, iOS: 2 > " platform
		Init $platform
		;;
	"q")
		TearDown
		;;
	*)
		echo "\033[0;31m𝘹 Error: Invalid Option\033[0m"
		;;
	esac
}
# End
TearDown() {
	clear
	case $platform in 
		"android")
			;;
		"ios")
			idb kill
			sleep 1
			kill $(pgrep -f idb | tr '\n' '\t')
			;;
	esac
	exit 1
}
###############
# Screen recored function
Recorder() {
	local package=$1
	case $platform in
	"android")
		if [[ -n $package ]]; then
			CheckApp $package
			if [[ $? == 0 ]]; then
				echo "\033[0;33m𝘹 Warming: 因未開啟所指定的 App ($package)，故將會記錄所有 Device Log\033[0m"
				local package=""
			fi
		fi
		Screenrecord
		Logcat $package
		;;
	"ios")
		Screenrecord
		Logcat
		;;
	esac
}
# Screen recored sub-function
CheckApp() {
	local package=$1
	if [[ $androidVersionOver7 == 1 ]]; then
		local isExist=$(adb shell pidof $package)
		if [[ -z $isExist ]]; then
			return 0
		fi
	fi
	return 1
}
# Screen recored sub-function
Logcat() {
	local filename=Log-$startTime
	local package=$1

	echo "\033[1:34mGet Log File ...\033[0m"
	case $platform in 
	"android")
		if [[ -z $package ]]; then
			adb logcat -t "$logStartTime" >$basePath/$folderName/$filename.log
		else
			if [[ $androidVersionOver7 == 1 ]]; then
				adb logcat -t "$logStartTime" --pid=$(adb shell pidof $package) >$basePath/$folderName/$filename.log
			elif [[ $androidVersionOver7 == 0 ]]; then
				adb logcat -t "$logStartTime" | grep $package >$basePath/$folderName/$filename.log
			fi
		fi
		;;
	"ios")
		nohup idb log --udid $target_device > $basePath/$folderName/$filename.log &
		;;
	esac
}
# Screen recored sub-function
Screenrecord() {
	logStartTime=$(date +"%m-%d %T.000")
	startTime=$(date +"%Y%m%d_%H%M%S")
	local filename=Screenrecord-$startTime

	echo "\033[1:34mStart recording ...\033[0m"
	case $platform in 
	"android")
		nohup adb shell screenrecord --size 480x800 /sdcard/$filename.mp4 &
		screenRecorderPID=$(pgrep -f screenrecord)
		read -n 1 -s -r -p "Press any key to stop recording ..."
		kill $screenRecorderPID
		sleep 1
		adb pull /sdcard/$filename.mp4 $basePath/$folderName
		adb shell rm -f /sdcard/$screenrecordFile.mp4
		;;
	"ios")
		nohup idb record video --udid $target_device $basePath/$folderName/$filename.mp4 &
		sleep 3
		nohup idb log --udid $target_device > $basePath/$folderName/$filename.log &
		sleep 3
		read -n 1 -s -r -p "Press any key to stop recording ..."
		idb kill
	esac
}
# Screen recored sub-function
Screenshot() {
	startTime=$(date +"%Y%m%d_%H%M%S")
	local filename=Screenshot-$startTime

	echo "\033[1:34mGet Screenshot ...\033[0m"
	case $platform in 
	"android")
		adb shell screencap -p /sdcard/$filename.png
		adb pull /sdcard/$filename.png $basePath/$folderName
		adb shell rm -f /sdcard/$filename.png
		;;
	"ios")
		idb screenshot --udid $target_device $basePath/$folderName/$filename.png
		;;
	esac
}

# ----------------------------------------------

echo "Enter your test platform :"
read -p "Android: 1, iOS: 2 > " platform
case $platform in 
"1")
	platform="android"
	;;
"2")
	platform="ios"
	;;
*)
	echo "\033[0;31m𝘹 Error: Invalid Option\033[0m"
	exit 1
	;;
esac

Init $platform
while [ 1 ]; do
	echo ""
	MainProcess $platform
done