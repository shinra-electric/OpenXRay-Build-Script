#!/usr/bin/env zsh

# ANSI color codes
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# This gets the location that the script is being run from and moves there.
export WORKDIR=${0:a:h}
cd "$WORKDIR"

# Detect CPU architecture
ARCH_NAME="$(uname -m)"

# Set found data var
FOUND_DATA=true

# Introduction
echo -e "${PURPLE}This script will build OpenXRay as a native macOS app bundle${NC}"
echo -e "${PURPLE}If it is run for the first time, it will also copy the game data to your Application Support folder${NC}\n"
echo -e "${PURPLE}You need to have the original game data in the same folder as this script${NC}"

echo "Important: \nThe script can be run from Terminal using the ${GREEN}zsh build_OpenXRay.sh${NC} command"
echo "It can also be run by simply using ${GREEN}./build_OpenXRay.sh'${NC}"
echo "It will not work correctly when using ${RED}sh source_engine_build.sh${NC}"
echo "Alternatively, use Finder to set the default application for the script to be Terminal and double-click to open\n"

# Functions for checking for Homebrew installation
homebrew_check() {
	echo "${PURPLE}Checking for Homebrew...${NC}"
	if ! command -v brew &> /dev/null; then
		echo -e "${PURPLE}Homebrew not found. Installing Homebrew...${NC}"
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		if [[ "${ARCH_NAME}" == "arm64" ]]; then 
			(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> $HOME/.zprofile
			eval "$(/opt/homebrew/bin/brew shellenv)"
			else 
			(echo; echo 'eval "$(/usr/local/bin/brew shellenv)"') >> $HOME/.zprofile
			eval "$(/usr/local/bin/brew shellenv)"
		fi
		
		# Check for errors
		if [ $? -ne 0 ]; then
			echo "${RED}There was an issue installing Homebrew${NC}"
			echo "${PURPLE}Quitting script...${NC}"	
			exit 1
		fi
	else
		echo -e "${PURPLE}Homebrew found. Updating Homebrew...${NC}"
		brew update
	fi
}

## Homebrew dependencies
# Install required dependencies
# Function for checking for an individual dependency
single_dependency_check() {
	if [ -d "$(brew --prefix)/opt/$1" ]; then
		echo -e "${GREEN}Found $1. Checking for updates...${NC}"
			brew upgrade $1
	else
		 echo -e "${PURPLE}Did not find $1. Installing...${NC}"
		brew install $1
	fi
}

# Install required dependencies
check_all_dependencies() {
	echo -e "${PURPLE}Checking for Homebrew dependencies...${NC}"
	# Required Homebrew packages
	deps=( cmake dylibbundler glew libogg libvorbis lzo sdl2 theora )
	
	for dep in $deps[@]
	do 
		single_dependency_check $dep
	done
}

check_data() {
	if [ -d "${WORKDIR}/$1" ]; then 
		echo -e "${GREEN}Found \"$1\" game data folder${NC}"
	else
		echo -e "${RED}Couldn't find the \"$1\" game data folder${NC}"
		FOUND_DATA=false
	fi
}

PS3='Would you like to continue? '
OPTIONS=(
	"Yes"
	"Quit")
select opt in $OPTIONS[@]
do
	case $opt in
		"Yes")
			homebrew_check
			check_all_dependencies
			check_data levels
			check_data localization
			check_data mp
			check_data patches
			check_data resources
			
			if [ "$FOUND_DATA" = false ]; then 
				echo -e "${PURPLE}The script will not attempt to copy game data${NC}"
			fi
			
			break
			;;
		"Quit")
			echo -e "${RED}Quitting${NC}"
			exit 0
			;;
		*) 
		echo "\"$REPLY\" is not one of the options..."
		echo "Enter the number of the option and press enter to select"
		;;
	esac
done

# Clone or Update Repository
if [ ! -d "xray-16" ]; then
	echo "${PURPLE}Cloning xray-16 repository...${NC}"
	git clone --recursive https://github.com/OpenXRay/xray-16
	cd xray-16
else
	echo "${PURPLE}xray-16 repository already exists. Updating...${NC}"
	cd xray-16
	rm -rf build
	rm -rf bin
	git pull origin dev

	echo -e "${PURPLE}Updating submodules...${NC}"

	# Update submodules
	git submodule update --init --recursive
fi

# Configure build system
cmake -B build \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_UNITY_BUILD=ON \
	-DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
	-DCMAKE_FIND_FRAMEWORK=LAST

# Build
echo -e "${PURPLE}Building...${NC}"
make -C build

# Check that building was successful
if [ $? -ne 0 ]; then
	echo -e "${RED}Building failed${NC}"
	exit 1
fi 

# Move back to the main directory
cd $WORKDIR

# Create app bundle structure
rm -rf OpenXRay.app
mkdir -p OpenXRay.app/Contents/Resources
mkdir -p OpenXRay.app/Contents/MacOS
mkdir -p OpenXRay.app/Contents/libs

# create Info.plist
PLIST="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
	<key>CFBundleGetInfoString</key>
	<string>OpenXRay</string>
	<key>CFBundleExecutable</key>
	<string>xr_3da</string>
	<key>CFBundleIconFile</key>
	<string>openxray.icns</string>
	<key>CFBundleIdentifier</key>
	<string>com.openxray.xray-16</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>OpenXRay</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1.0</string>
	<key>LSMinimumSystemVersion</key>
	<string>12.0</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSHumanReadableCopyright</key>
	<string>OpenXRay Team</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.games</string>
</dict>
</plist>
"
echo "${PLIST}" > "OpenXRay.app/Contents/Info.plist"

# Create PkgInfo
PKGINFO="-n APPLOPXR"
echo "${PKGINFO}" > "OpenXRay.app/Contents/PkgInfo"

# Get an icon from macosicons.com
curl -o OpenXRay.app/Contents/Resources/openxray.icns https://parsefiles.back4app.com/JPaQcFfEEQ1ePBxbf6wvzkPMEqKYHhPYv8boI1Rc/40e1f123afdd4c46e6c8e2da71ce2053_S.T.A.L.K.E.R_-_Call_of_Pripyat.icns

# Bundle resources. 
mv xray-16/bin/arm64/Release/xr_3da OpenXRay.app/Contents/MacOS
mv xray-16/bin/arm64/Release/*.dylib OpenXRay.app/Contents/libs/
mv xray-16/bin/arm64/Release/*.a OpenXRay.app/Contents/libs/

install_name_tool -change @rpath/xrEngine.dylib @executable_path/../libs/xrEngine.dylib OpenXRay.app/Contents/MacOS/xr_3da
install_name_tool -change @rpath/xrGame.dylib @executable_path/../libs/xrGame.dylib OpenXRay.app/Contents/MacOS/xr_3da
install_name_tool -change @rpath/xrAPI.dylib @executable_path/../libs/xrAPI.dylib OpenXRay.app/Contents/MacOS/xr_3da
install_name_tool -change @rpath/xrCore.dylib @executable_path/../libs/xrCore.dylib OpenXRay.app/Contents/MacOS/xr_3da

dylibbundler -of -cd -b -x OpenXRay.app/Contents/MacOS/xr_3da -d OpenXRay.app/Contents/libs/

# Check that the build was successful
if [ $? -ne 0 ]; then
	echo -e "${RED}Failure creating the app bundle...${NC}"
	exit 1
else 
	echo -e "${PURPLE}App bundle created successfully...${NC}"
fi 

# Copy game data to Application Support
APP_SUPP=~/Library/Application\ Support/GSC\ Game\ World/S.T.A.L.K.E.R.\ -\ Call\ of\ Pripyat

if [ "$FOUND_DATA" = true ]; then 
	if [ ! -d $APP_SUPP ]; then
		echo "${PURPLE}Application Support folder not found. Creating...${NC}"
		mkdir -p $APP_SUPP
		echo "${PURPLE}Copying game data...${NC}"
		cp -R levels localization mp patches resources $APP_SUPP
	else 
		echo "${PURPLE}Existing Application Support folder found. Not copying game data...${NC}"
	fi
fi

# These newly built files should overwrite any existing versions
rm -rf $APP_SUPP/gamedata
cp -R xray-16/res/gamedata $APP_SUPP
cp xray-16/res/fsgame.ltx $APP_SUPP/fsgame.ltx

if [ $? -eq 0 ]; then
	echo "${PURPLE}Cleaning up...${NC}"
	rm -rf xray-16 
fi 

echo "${PURPLE}Script completed${NC}"
