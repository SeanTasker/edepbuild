#! /bin/bash
### -====================================-
### Echo automated dependency build script
### -====================================-
### You must specify a target platform.
###
### $($(args[0])) targetName [library]
###
### NOTE: This is the Powershell version of edepbuild from Echo https://developer.emblem.net.au/source/echo3/
### Requirements do vary slightly to the bash implementation but the main behaviour is the same.
###
### If you specify a 'library' then only that library is built.
###
### NOTE: the scripts/platform/build.config file defines what to build and the order. You need to update this when
### adding a new dependency.
###
### edepbuild uses scripts in the scripts/{PLATFORM} folder. These define how the dependency should be built.
### The default process is to use configure and make to build each target but the target script files can override
### any aspect of the build process.
###
### There are two ways to control a dependency build.
###
### 1. Simple - Set some variables to define how configure or cmake are used
### 2. Custom - Override build functions to control part of all aspects of a build
###
### In both situations this script will perform the following operations in order
###
###     download
###     extract
###     patch_prepare
###     prepare
###     patch_build
###     build
###     patch_install
###     install
###
### - The download step is performed from the X directory and should download the ARCHIVE_NAME to the X folder.
### - The extract step can be skipped by setting NO_EXTRACT=1 before invoking the $0.
### - The build directory is removed before extracting to ensure a clean build environment for the dependency
###   This can be skipped by setting NO_REMOVE_BUILD_DIR=1 before invoking $0
###
### All other steps are executed from the build/platform/dependency folder
###
### The extract step will extract ARCHIVE_NAME to the dependency build folder and step out the first level folder
### in the archive. This assumes that every archive will contain a top level folder with the source in it. The
### resource for stripping this top level folder is there can be a lot of variation about the name of this folder
### so instead we extract the contents of the folder into the dependency build folder.
###
### The patch_* steps are no op steps that can be overridden if custom behaviour is required before the normal
### build steps. Each other step can be overridden as defined below.
###
### - Simple -
### If a dependency follows common build processes and just needs to be configured with some cmake or configure
### flags then the following variables can be used to customise the build.
### 
###     USE_CMAKE - defaults to 0 but if set to 1 cmake will be used instead of ./configure
###     DOWNLOAD_URL - The complete URL to download the archive from
###     ARCHIVE_NAME - The complete archive name, e.g. something.tar.gz. The default extract step assumes a tar
###                    archive. See - Custom - on how to override this.
###
### configure variables - used in the prepare step
###     CONFIGURE_OPTIONS - Any additional configure command line arguments
###
### cmake variables - used in the prepare step
###     CMAKE_BUILD_DIRECTORY - Defaults to "buildtemp" this will be created if it does not exist and used as the
###                             build folder.
###     CMAKE_DIRECTORY - Defaults to full/path/to/build/platform/dependency" , but if cmake needs to point
###                       to another directory this can be used to override. If a relative path is required or
###                       more useful then the directory this references from is CMAKE_BUILD_DIRECTORY
###     CMAKE_OPTIONS - Any additional cmake command line arguments for example to specify -DSOMETHING=ON If you
###                     need to specify multiple options you need to specify an array of strings in PowerShell for
###                     example $CMAKE_OPTIONS="-DSOMETHING=ON","-DSOMETHINGELSE=Fast"
###
### Make options - used in the build step
###     MAKE_OPTIONS - Additional options used when running make
###
### - Custom -
### Any of the above listed steps are implemented as functions. These can be overridden in a script by
### defining the function again as:
###
###     function step()
###     {
###         echo "Custom command"
###     }
###
### For example, if you want to override the build step so that GNU make is not used then you can include:
###
###     function build()
###     {
###         echo "Custom build process started"
###     }
###
### NOTE: a build step cannot be empty or it will result in error. This is a bash limitation. So at minimum you
### should output a message indicating that you have skipped a step.
###
### Sometimes additional steps are required before prepare, build or install. The steps patch_prepare,
### patch_build and patch_install can be used to insert additional processing but still stick to the default
### step. This can be useful if a patch is required for building on a specific platform for example.
###
### The step definitions are reset for each dependency so your step won't affect another build.
###
### = Additional script notes =
### The scripts are executed by using source. So it is possible to include commands in the script. This is how
### custom builds used to be implemented. This does mean you can execute arbitrary commands before any steps
### are executed. This typically isn't advised though as it might lead to confusion.
###
### It is possible to set environment variables that persist for dependencies that follow.
###
### You can override the following settings when running
###
### CMAKE_GEN - "Visual Studio 17 2022"
### CMAKE_GEN_ARCH - "x64"
### BUILD_CONFIGURATION - "RelWithDebInfo Release Debug"
###
### The install location for the build results will go to:
###
### ECHO_INSTALL_DIR - "installed"
###
### You can increase the number of threads for parallel builds by setting NUM_BUILD_THREADS this defaults to
### 8.
###
### NOTE: It is recommended that you have cmake installed to your system. Running this script will detect if
### cmake is available and install if to the tools folder, but you may wish to use cmake outside of this
### script context.
### -====================================-
###

if ( "$($args[0])" -eq "" ) {
	(cat $MyInvocation.MyCommand) -match "^###"
	exit
}

function VarOrDefault
{
	$outValue = Get-VAriable -Name "$($args[0])" -ValueOnly -scope Global -ea SilentlyContinue
	if($outValue -eq $null)
	{
		return "$($args[1])"
	}
	return $outValue
}

$Env:ECHO_PLATFORM=$args[0]
$ONLY_LIB=$args[1]

$ECHO_INSTALL_DIR = VarOrDefault "ECHO_INSTALL_DIR" "dependencies"
$BUILD_CONFIGURATION=VarOrDefault "BUILD_CONFIGURATION" "RelWithDebInfo Release Debug"
$TOOLS_DIR=VarOrDefault "TOOLS_DIR" "tools"
$CMAKE_GEN=VarOrDefault "CMAKE_GEN" "Visual Studio 17 2022"
$CMAKE_GEN_ARCH=VarOrDefault "CMAKE_GEN_ARCH" "x64"
$ECHO_X_DIR=VarOrDefault "ECHO_X_DIR" "X"
$NO_REMOVE_BUILD_DIR=VarOrDefault "NO_REMOVE_BUILD_DIR" "0"
$NO_EXTRACT=VarOrDefault "NO_EXTRACT" "0"
$NUM_BUILD_THREADS=VarOrDefault "NUM_BUILD_THREADS" "8"
$ECHO_DEP_ROOT_DIR=$pwd.Path
$ECHO_DEP_BUILD_DIR="$ECHO_DEP_ROOT_DIR/build"
$Env:ECHO_DEP_SCRIPTS_DIR="$ECHO_DEP_ROOT_DIR/scripts"

echo "ECHO_INSTALL_DIR: $ECHO_INSTALL_DIR"
echo "ECHO_X_DIR: $ECHO_X_DIR"
echo "NO_REMOVE_BUILD_DIR: $NO_REMOVE_BUILD_DIR"
echo "NO_EXTRACT: $NO_EXTRACT"
echo "NUM_BUILD_THREADS: $NUM_BUILD_THREADS"
echo "ECHO_DEP_ROOT_DIR: $ECHO_DEP_ROOT_DIR"
echo "ECHO_DEP_BUILD_DIR: $ECHO_DEP_BUILD_DIR"
echo "TOOLS_DIR: $TOOLS_DIR"
echo "Env:ECHO_DEP_SCRIPTS_DIR $Env:ECHO_DEP_SCRIPTS_DIR"
echo "CMAKE_GEN: $CMAKE_GEN"
echo "CMAKE_GEN_ARCH: $CMAKE_GEN_ARCH"
echo "BUILD_CONFIGURATION: $BUILD_CONFIGURATION"

if ("$ONLY_LIB" -eq "")
{
	if ( Test-Path "$Env:ECHO_DEP_SCRIPTS_DIR/$Env:ECHO_PLATFORM/build.config" )
	{
		$content = [string]::join([environment]::newline,(get-content "$Env:ECHO_DEP_SCRIPTS_DIR/$Env:ECHO_PLATFORM/build.config"))
		Invoke-Expression $content
	} else {
		echo "$Env:ECHO_DEP_SCRIPTS_DIR/$Env:ECHO_PLATFORM/build.config does not exist. Unable to determine what to build." 
		exit 1;
	}
} else {
	$Env:BUILD_ORDER="$ONLY_LIB"
}

if ("$Env:BUILD_ORDER" -eq "" )
{
	echo "Nothing to build. Make sure you set `$Env:BUILD_ORDER in $Env:ECHO_DEP_SCRIPTS_DIR/$Env:ECHO_PLATFORM/build.config"
	exit 1;
}

#Check for the platform build directory and create if necesary 
if ( Test-Path "$ECHO_DEP_BUILD_DIR/$Env:ECHO_PLATFORM" )
{
	echo "Platform directory exists - $ECHO_DEP_BUILD_DIR/$Env:ECHO_PLATFORM"
} else
{
	echo "Creating platform directory - $ECHO_DEP_BUILD_DIR/$Env:ECHO_PLATFORM"
	mkdir "$ECHO_DEP_BUILD_DIR/$Env:ECHO_PLATFORM"
}

#Get the absolute path of the root directory
$ECHO_ROOT_DIR=$pwd.Path
$Env:Path="$Env:Path;${ECHO_DEP_ROOT_DIR}/${TOOLS_DIR}/bin"

echo "Build order: $Env:BUILD_ORDER"

$CLEAN_PATH=$Env:PATH

# Check for platform config
if ( -not (Test-Path "$Env:ECHO_DEP_SCRIPTS_DIR/$Env:ECHO_PLATFORM/$Env:ECHO_PLATFORM.config") )
{
	echo "------------------------------"
	echo "Please add a platform config file: $Env:ECHO_PLATFORM"
	echo "------------------------------"
	exit 1
}

function SetupCommand
{
	$command = $($args[0])
	$url = $($args[1])
	$archive = "temp.tar.gz"
	# Check if required commands exist
	Get-Command $command -ErrorVariable CMD_TEST_ERROR
	if ("$CMD_TEST_ERROR" -eq "")
	{
		echo "$command is available"
	}else
	{
		echo "$command is not available I will attempt to install it from: $url"
		if( -not (Test-Path "${ECHO_DEP_ROOT_DIR}/${TOOLS_DIR}"))
		{
			mkdir "${ECHO_DEP_ROOT_DIR}/${TOOLS_DIR}"
		}
		cd "${ECHO_DEP_ROOT_DIR}/${TOOLS_DIR}"
		curl.exe -L $url -o $archive
		if (-not ("$LASTEXITCODE" -eq "0") ) 
		{
			echo "Could not download and install $command is not available"
			Exit 1
		}
		if (-not (Test-Path "$archive"))
		{
			echo "Temporary archive was not written. Unable to install $command"
			exit 1
		}

		echo "Extracting command $cmake"

		tar -xzf "${archive}" --strip-components=1

		if ( -not ($LASTEXITCODE -eq 0 ) )
		{
			# If there was an error the file might be a HTTP error so try and output it
			Get-Content "${archive}" -Tail 20
			exit 1;
		}
		rm $archive

		Get-Command $command -ErrorVariable CMD_TEST_ERROR
		if ("$CMD_TEST_ERROR" -eq "")
		{
			echo "$command is now available"
		}else
		{
			echo "Successfully extracted archive to tools folder but the command is still not available."
		}

		cd "${ECHO_DEP_ROOT_DIR}"
	}
}

SetupCommand cmake "https://github.com/Kitware/CMake/releases/download/v3.29.1/cmake-3.29.1-windows-x86_64.zip"

function ExitAndRestore
{
	cd "$ECHO_ROOT_DIR"
	$Env:PATH=$CLEAN_PATH
	exit $($args[0])
}

$BuildConfigurationList = $BUILD_CONFIGURATION.split(" ");

foreach( $targetConfiguration in $BuildConfigurationList )
{
	$ECHO_LIB_DIR="${ECHO_INSTALL_DIR}/$Env:ECHO_PLATFORM/$CMAKE_GEN_ARCH/$targetConfiguration"

	echo "Building target configuration: $targetConfiguration"
	echo "ECHO_LIB_DIR: $ECHO_LIB_DIR"

	#Check for the lib platform directory and create if necesary 
	if ( Test-Path "$ECHO_LIB_DIR" )
	{
		echo "Lib target directory exists - $ECHO_LIB_DIR"
	}else
	{
		echo "Creating lib target directory - $ECHO_LIB_DIR"
		mkdir "$ECHO_LIB_DIR"
	}

	#Get the absolute path of the lib platform directory
	cd "$ECHO_LIB_DIR"
	$ECHO_LIB_DIR=$pwd.Path

	# #For each folder in the platform directory
	$BuildList = $Env:BUILD_ORDER.split(" ");
	foreach ($libDirectory in $BuildList)
	{	
		$MAKE_FILE=""
		#Change to platform build folder
		if( -not (Test-Path "${ECHO_DEP_ROOT_DIR}/${ECHO_X_DIR}/${libDirectory}"))
		{
			mkdir "${ECHO_DEP_ROOT_DIR}/${ECHO_X_DIR}/${libDirectory}"
		}
		cd "${ECHO_DEP_ROOT_DIR}/${ECHO_X_DIR}/${libDirectory}"
		echo "------------------------------"
		echo "$libDirectory"
		echo "------------------------------"
		$ECHO_CONFIG_FILE="$Env:ECHO_DEP_SCRIPTS_DIR/$Env:ECHO_PLATFORM/$Env:ECHO_PLATFORM-$libDirectory.config"
		if ( -not (Test-Path "$ECHO_CONFIG_FILE" ) )
		{
			echo "Library platform edepbuild configuration file not found. Please create \"$ECHO_CONFIG_FILE\" and set at least DOWNLOAD_URL"
			ExitAndRestore 1
		}

		$USE_CMAKE=0
		$CONFIGURE_OPTIONS=""
		$CMAKE_OPTIONS=""
		$CMAKE_DIRECTORY="${ECHO_DEP_BUILD_DIR}/$Env:ECHO_PLATFORM/${libDirectory}"
		$CMAKE_BUILD_DIRECTORY="buildtemp"
		$MAKE_OPTIONS=""
		$PKG_CONFIG_PATH="${ECHO_LIB_DIR}/lib/pkgconfig"
		Remove-Variable -erroraction 'silentlycontinue' DOWNLOAD_URL
		Remove-Variable -erroraction 'silentlycontinue' ARCHIVE_NAME

		function download()
		{
			if ("$DOWNLOAD_URL" -eq "" )
			{
				$DOWNLOAD_URL="https://www.emblem.net.au/ed/${libDirectory}/${ARCHIVE_NAME}.tar.gz"
			}
			if ( "$ARCHIVE_NAME" -eq "" )
			{
				echo "Missing ARCHIVE_NAME for archive download"
				ExitAndRestore 1;
			}
			if ( -not (Test-Path "${ARCHIVE_NAME}" ) )
			{
				echo "Currently in: $pwd.Path"
				echo "Downloading: ${DOWNLOAD_URL} to ${ARCHIVE_NAME}"
				curl.exe -L ${DOWNLOAD_URL} -o ${ARCHIVE_NAME}
				if (-not ("$LASTEXITCODE" -eq "0") ) 
				{
					echo "edepbuild: There were errors downloading."
					ExitAndRestore 1;
				}
				if (Test-Path "${ARCHIVE_NAME}" )
				{
					echo "${ARCHIVE_NAME} is here"
				}
			}else
			{
				echo "${ARCHIVE_NAME} exists. Download skipped."
			}
		}

		function extract()
		{
			echo "edepbuild: extract ${ECHO_DEP_ROOT_DIR}/${ECHO_X_DIR}/${libDirectory}/${ARCHIVE_NAME}"
			tar -xzf "${ECHO_DEP_ROOT_DIR}/${ECHO_X_DIR}/${libDirectory}/${ARCHIVE_NAME}" --strip-components=1

			if ( -not ($LASTEXITCODE -eq 0 ) )
			{
				Get-Content "${ECHO_DEP_ROOT_DIR}/${ECHO_X_DIR}/${libDirectory}/${ARCHIVE_NAME}" -Tail 20
				echo "edepbuild: There were errors extracting."
				rm ${ECHO_DEP_ROOT_DIR}/${ECHO_X_DIR}/${libDirectory}/${ARCHIVE_NAME}
				ExitAndRestore 1;
			}
		}

		function patch_prepare()
		{
			echo "edepbuild: No prepare patch"
		}

		function prepare()
		{
			if ( "$USE_CMAKE" -eq "0" )
			{
				echo "Currently only CMake projects are supported. Please feel free to add support for other environments"
				#chmod +x configure
				#./configure --prefix=$ECHO_LIB_DIR $CONFIGURE_OPTIONS
			}else
			{
				if(-not (Test-Path "${CMAKE_BUILD_DIRECTORY}"))
				{
					echo "Creating build directory: ${CMAKE_BUILD_DIRECTORY}"
					mkdir "${CMAKE_BUILD_DIRECTORY}"
				}else
				{
					echo "Build directory exists: ${CMAKE_BUILD_DIRECTORY}"
				}
				cd "${CMAKE_BUILD_DIRECTORY}"
				echo "Using cmake directory: ${CMAKE_DIRECTORY}"
				cmake "${CMAKE_DIRECTORY}" -DCMAKE_FIND_ROOT_PATH="${ECHO_LIB_DIR}" -DCMAKE_PREFIX_PATH="${ECHO_LIB_DIR}" -DCMAKE_INSTALL_PREFIX="${ECHO_LIB_DIR}" -DCMAKE_INSTALL_RPATH="${ECHO_LIB_DIR}" -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE $CMAKE_OPTIONS_PLATFORM $CMAKE_OPTIONS -G "$CMAKE_GEN" -A "${CMAKE_GEN_ARCH}"
			}
			
			if ( $LASTEXITCODE -eq 0 )
			{
				echo "edepbuild: $Env:ECHO_PLATFORM-$libDirectory prepare step complete"
			}else
			{
				echo "edepbuild: error: $Env:ECHO_PLATFORM-$libDirectory prepare failed"
				ExitAndRestore 1
			}
		}

		function patch_build()
		{
			echo "edepbuild: No build patch"
		}

		function build()
		{
			echo "Need to execute msbuild"
			cmake --build . --config "${targetConfiguration}" -j $NUM_BUILD_THREADS

			if ( $LASTEXITCODE -ne 0 )
			{
				echo "edepbuild: error: $Env:ECHO_PLATFORM-$libDirectory build failed"
				ExitAndRestore 1
			} else
			{
				echo "edepbuild: build $libDirectory complete"
			}
		}

		function patch_install()
		{
			echo "edepbuild: No install patch"
		}

		function install()
		{
			cmake --build . --target install --config "${targetConfiguration}"
			if ( $LASTEXITCODE -ne 0 )
			{
				echo "edepbuild: error: $Env:ECHO_PLATFORM-$libDirectory make install failed"
				ExitAndRestore 1
			}
		}

		function post_install()
		{
			echo "edepbuild: No post install step"
		}

		$content = [string]::join([environment]::newline,(get-content "$Env:ECHO_DEP_SCRIPTS_DIR/$Env:ECHO_PLATFORM/$Env:ECHO_PLATFORM.config"))
		Invoke-Expression $content
		$content = [string]::join([environment]::newline,(get-content "$ECHO_CONFIG_FILE"))
		Invoke-Expression $content

		download

		cd "$ECHO_DEP_BUILD_DIR/$Env:ECHO_PLATFORM"

		if ( (Test-Path "${libDirectory}") -and ("${NO_REMOVE_BUILD_DIR}" -eq "0") )
		{
			echo "edepbuild: removing build directory: ${libDirectory}"
			rm -R -fo ${libDirectory}
		}

		if( -not (Test-Path "$libDirectory"))
		{
			mkdir "$libDirectory"
		}
		cd "$libDirectory"

		if ( "${NO_EXTRACT}" -eq "0" )
		{
			extract
		}

		patch_prepare
		prepare
		patch_build
		build
		patch_install
		install
		post_install

		$Env:PATH=$CLEAN_PATH
		echo "edepbuild: Finished $libDirectory"
	}
	cd "$ECHO_ROOT_DIR"
}
