#!/bin/sh
set -e

PKG=$(pkg_info | grep -E '^(apache-ant|jdk|openal|maven|rsync|lwjgl|xz|gradle)\-' | wc -l)
if [ "$PKG" -eq 8 ]
then
	echo "Packages installed: OK"
else
	echo "Packages missing. Required packages are apache-ant, jdk, openal, maven, rsync, lwjgl, xz, gradle"
	exit 1
fi

if [ ! -f delver.jar ]
then
	echo "You need to have the file delver.jar in the current folder. You can find it in the files of the game installed via Steam (use depotdownloader)"
	exit 2
fi

if [ ! -f delverengine-1.2.0.tar.gz ]
then
	ftp -o delverengine-1.2.0.tar.gz \
		https://github.com/Interrupt/delverengine/archive/v1.2.0.tar.gz
fi

# build engine
ftp https://raw.githubusercontent.com/reivyr/openbsd-delver/master/delverengine-1.2.0.diff
tar zxfv delverengine-1.2.0.tar.gz
patch -p0 < delverengine-1.2.0.diff
cd delverengine-1.2.0
gradle DungeoneerDesktop:processResources
gradle DungeoneerDesktop:dist
cd ..

# extract
mkdir unjar
cd unjar
GAME_FOLDER=$PWD
/usr/local/jdk*/bin/jar xvf ../delver.jar

# remove java files
rm -fr com/badlogic

# copy libs
cp /usr/local/share/lwjgl/liblwjgl64.so liblwjgl64.so
cp /usr/local/lib/libopenal.so.* libopenal64.so 

# download and extract libgdx-openbsd
ftp https://perso.pw/gaming/libgdx199-openbsd-0.0.tar.xz
unxz < libgdx199-openbsd-0.0.tar.xz | tar xvf -

# build some so files
cd $GAME_FOLDER/libgdx-openbsd/gdx/jni && ant -f build-openbsd64.xml
cd $GAME_FOLDER/libgdx-openbsd/extensions/gdx-freetype/jni && ant -f build-openbsd64.xml 

# copy so files
cd $GAME_FOLDER
find libgdx-openbsd -type f -name '*.so' -exec cp {} . \;

cd $GAME_FOLDER/libgdx-openbsd/extensions/gdx-jnigen && mvn package && \
	rsync -avh target/classes/com/ $GAME_FOLDER/com/
cd $GAME_FOLDER/libgdx-openbsd/gdx/ && mvn package && \
	rsync -avh target/classes/com/ $GAME_FOLDER/com/
cd $GAME_FOLDER/libgdx-openbsd/backends/gdx-backend-lwjgl/ && mvn package && \
	rsync -avh target/classes/com/ $GAME_FOLDER/com/
cd $GAME_FOLDER/libgdx-openbsd/extensions/gdx-freetype && mvn package && \
	rsync -avh target/classes/com/ $GAME_FOLDER/com/
cd $GAME_FOLDER/libgdx-openbsd/extensions/gdx-controllers/gdx-controllers && \
	mvn package && rsync -avh target/classes/com/ $GAME_FOLDER/com/
cd $GAME_FOLDER/libgdx-openbsd/extensions/gdx-controllers/gdx-controllers-desktop && \
	mvn package && rsync -avh target/classes/com/ $GAME_FOLDER/com/

cd $GAME_FOLDER
cp -R ../delverengine-1.2.0/DungeoneerDesktop/build/classes/java/main/com/ .
cp -R ../delverengine-1.2.0/Dungeoneer/build/classes/java/main/com/ .

rm -rf $GAME_FOLDER/../delverengine-1.2.0

echo "You can run the game with the following command in the 'unjar' directory:"
echo "/usr/local/jdk-1.8.0/bin/java -Dsun.java2d.dpiaware=true com.interrupt.dungeoneer.DesktopStarter"
