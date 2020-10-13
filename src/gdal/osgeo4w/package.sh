export P=gdal
export V=3.1.3
export B=next
export MAINTAINER=JuergenFischer
export BUILDDEPENDS="python3-core swig zlib-devel proj-devel libtiff-devel libpng-devel curl-devel geos-devel libmysql-devel sqlite3-devel netcdf-devel libpq-devel expat-devel xerces-c-devel szip-devel hdf4-devel hdf5-devel ogdi-devel libiconv-devel openjpeg-devel libspatialite-devel freexl-devel libkml-devel xz-devel zstd-devel msodbcsql-devel poppler-devel libgeotiff-devel libwebp-devel oci-devel openfyba-devel freetype-devel python3-devel python3-numpy"
# libjpeg-devel libjpeg12-devel

source ../../../scripts/build-helpers

# TODO: revive (unused) csharp

startlog

[ -f $P-$V.tar.gz ] || wget -q https://github.com/OSGeo/$P/releases/download/v$V/$P-$V.tar.gz
[ -f ../makefile.vc ] || tar -C .. -xzf $P-$V.tar.gz --xform "s,^$P-$V,.,"
[ -f patched ] || {
	patch -p1 --dry-run -d.. <patch
	patch -p1 -d.. <patch
	touch patched
}

mkdir -p gdaldeps
cd gdaldeps

export MRSID_SDK=MrSID_DSDK-9.5.4.4703-win64-vc14
export ECW_ZIP=erdas-ecw-sdk-5.3.0-win.zip
export ECW_EXE=ECWJP2SDKSetup_5.3.0.exe

for i in \
	https://raw.githubusercontent.com/Esri/file-geodatabase-api/master/FileGDB_API_1.5/FileGDB_API_1_5_VS2015.zip \
	http://downloads.hexagongeospatial.com/software/2016/ECWJP2SDK/erdas-ecw-sdk-5.3.0-win.zip \
	http://bin.lizardtech.com/download/developer/$MRSID_SDK.zip \
	; do
	[ -f "${i##*/}" ] || wget -q "$i"
done

mkdir -p filegdb
[ -d filegdb/lib64 ] || unzip -q -o -d filegdb FileGDB_API_1_5_VS2015.zip "bin64/*" "lib64/*" "include/*" license/userestrictions.txt

mkdir -p ecw
[ -f $ECW_EXE ] || unzip -q $ECW_ZIP $ECW_EXE
[ -d ecw/lib ] || {
	7z x -aoa -oecw $ECW_EXE \
		'$0/include/*' \
		'lib/vc140/x64/*' \
		'bin/vc140/x64/*' \
		'ERDAS_ECW_JPEG2000_SDK.pdf'
	mv 'ecw/$0/include' ecw/include
	rmdir 'ecw/$0'
}
[ -d $MRSID_SDK ] || {
	unzip -o -q $MRSID_SDK.zip \
		"$MRSID_SDK/Raster_DSDK/include/*" \
		"$MRSID_SDK/Raster_DSDK/lib/*" \
		"$MRSID_SDK/Lidar_DSDK/include/*" \
		"$MRSID_SDK/Lidar_DSDK/lib/*" \
		"$MRSID_SDK/LICENSE.pdf"

	# 'add' VC2019 support
	cp "$MRSID_SDK/Raster_DSDK/include/lt_platform.h" "$MRSID_SDK/Raster_DSDK/include/lt_platform.h.orig"
	sed -i -e 's/#elif defined(_MSC_VER) &&  (1300 <= _MSC_VER && _MSC_VER <= 1910)/#elif defined(_MSC_VER) \&\& (1300 <= _MSC_VER \&\& _MSC_VER < 1930)/' \
		"$MRSID_SDK/Raster_DSDK/include/lt_platform.h"
}

cd ..

export PYTHON=Python39

R=$OSGEO4W_REP/x86_64/release/$P
mkdir -p $R/$P-{oracle,filegdb,ecw,mrsid,sosi,mss,hdf5} $R/python3-$P

if [ -f $R/$P-$V-$B-src.tar.bz2 ]; then
	echo "$R/$P-$V-$B-src.tar.bz2 already exists - skipping"
	continue
fi

export EXT_NMAKE_OPT=$(cygpath -am $PWD/nmake.opt)
export FGDB_SDK=$(cygpath -am gdaldeps/filegdb)
export ECW_SDK=$(cygpath -am gdaldeps/ecw)
export MRSID_SDK=$(cygpath -am gdaldeps/$MRSID_SDK)

export DESTDIR=$PWD/install
export PYDESTDIR=$PWD/pyinstall

rm -rf $DESTDIR $PYDESTDIR

mkdir -p $DESTDIR/etc/ini
mkdir -p $DESTDIR/share/gdal
mkdir -p $PYDESTDIR/etc/preremove

cd ..

(
	fetchenv osgeo4w/osgeo4w/bin/o4w_env.bat
	vs2019env
	export PATH=$PATH:/bin

	for i in clean default install devinstall; do
		[ -f osgeo4w/no$i ] && continue


		nmake /f makefile.vc \
			OSGEO4W=$(cygpath -aw osgeo4w/osgeo4w) \
			EXT_NMAKE_OPT=$(cygpath -aw osgeo4w/nmake.opt) \
			GDAL_HOME=$(cygpath -aw $DESTDIR) \
			ECWDIR=$(cygpath -aw $ECW_SDK) \
			FGDB_SDK=$(cygpath -aw $FGDB_SDK) \
			MRSID_SDK=$(cygpath -aw $MRSID_SDK) \
			VCDIR="$VCToolsInstallDir" \
			$i
	done

	[ -f osgeo4w/nopackage ] && exit

	cd swig

	unset INCLUDE LIB
	nmake /f makefile.vc \
		PYDIR=$(cygpath -aw ../osgeo4w/osgeo4w/apps/$PYTHON) \
		SWIG=$(cygpath -aw ../osgeo4w/osgeo4w/bin/swig.bat) \
		EXT_NMAKE_OPT=$(cygpath -aw ../osgeo4w/nmake.opt) \
		clean python

	cd python

	# Fix CRLF => CRLFCR conversion.
	find build -name "*.py" -print | xargs /bin/flip -u

	mkdir -p $PYDESTDIR/apps/$P/$PYTHON
	python setup.py install \
		--prefix=$(cygpath -aw $PYDESTDIR/apps/$PYTHON) \
		--record $(cygpath -aw $OSGEO4W_PWD/python-record.log)
)

cd swig/python

mkdir -p $PYDESTDIR/bin
for i in scripts/*.py; do
	b=$(basename "$i" .py)
	cat <<EOF >$PYDESTDIR/apps/$PYTHON/Scripts/$b.bat
@echo off
call "%OSGEO4W_ROOT%\\bin\\o4w_env.bat"
python "%OSGEO4W_ROOT%\\apps\\$PYTHON\\$(cygpath -w "$i")" %%*
EOF
done

cd ../../osgeo4w

cat <<EOF >$DESTDIR/etc/ini/$P.bat
SET GDAL_DATA=%OSGEO4W_ROOT%\\share\\gdal
SET GDAL_DRIVER_PATH=%OSGEO4W_ROOT%\\bin\\gdalplugins
EOF

cat <<EOF >$PYDESTDIR/etc/preremove/python3-gdal.bat
python -B %PYTHONHOME%\\Scripts\\preremove-cached.py python3-gdal
EOF

cat <<EOF >$R/setup.hint
sdesc: "The GDAL/OGR library and commandline tools"
ldesc: "The GDAL/OGR library and commandline tools"
maintainer: $MAINTAINER
category: Libs Commandline_Utilities
requires: msvcrt2019 libtiff libpng proj curl geos libmysql sqlite3 netcdf libpq expat xerces-c hdf4 ogdi libiconv openjpeg spatialite freexl libkml xz zstd poppler libgeotiff
EOF
# libjpeg libjpeg12

cat <<EOF >$R/python3-$P/setup.hint
sdesc: "The GDAL/OGR Python3 Bindings and Scripts"
ldesc: "The GDAL/OGR Python3 Bindings and Scripts"
category: Libs
requires: $P python3-core python3-numpy
maintainer: $MAINTAINER
external-source: $P
EOF

cat <<EOF >$R/$P-oracle/setup.hint
sdesc: "OGR OCI and GDAL GeoRaster Plugins for Oracle"
ldesc: "OGR OCI and GDAL GeoRaster Plugins for Oracle"
category: Libs
requires: $P oci
maintainer: $MAINTAINER
external-source: $P
EOF

cat <<EOF >$R/$P-filegdb/setup.hint
sdesc: "OGR FileGDB Driver"
ldesc: "OGR FileGDB Driver"
category: Libs
maintainer: $MAINTAINER
requires: $P
external-source: $P
EOF

cat <<EOF >$R/$P-ecw/setup.hint
sdesc: "ECW Raster Plugin for GDAL"
ldesc: "ECW Raster Plugin for GDAL"
category: Libs
requires: $P
maintainer: $MAINTAINER
external-source: $P
EOF

cat <<EOF >$R/$P-mrsid/setup.hint
sdesc: "MrSID Raster Plugin for GDAL"
ldesc: "MrSID Raster Plugin for GDAL"
category: Libs
maintainer: $MAINTAINER
requires: $P
external-source: $P
EOF

cat <<EOF >$R/$P-sosi/setup.hint
sdesc: "OGR SOSI Driver"
ldesc: "The OGR SOSI Driver enables OGR to read data in Norwegian SOSI standard (.sos)"
category: Libs
requires: $P
maintainer: $MAINTAINER
external-source: $P
EOF

cat <<EOF >$R/$P-mss/setup.hint
sdesc: "OGR plugin with SQL Native Client support for MSSQL Bulk Copy"
ldesc: "OGR plugin with SQL Native Client support for MSSQL Bulk Copy"
category: Libs
requires: $P msodbcsql
maintainer: $MAINTAINER
external-source: $P
EOF

cat <<EOF >$R/$P-hdf5/setup.hint
sdesc: "HDF5 Plugin for GDAL"
ldesc: "HDF5 Plugin for GDAL"
category: Libs
maintainer: $MAINTAINER
requires: $P hdf5
external-source: $P
EOF

cp ../LICENSE.TXT $R/$P-$V-$B.txt
cp ../LICENSE.TXT $R/$P-oracle/$P-oracle-$V-$B.txt
cp ../LICENSE.TXT $R/$P-mss/$P-mss-$V-$B.txt
cp ../LICENSE.TXT $R/$P-sosi/$P-sosi-$V-$B.txt
cp ../LICENSE.TXT $R/python3-$P/python3-$P-$V-$B.txt
cp $FGDB_SDK/license/userestrictions.txt $R/$P-filegdb/$P-filegdb-$V-$B.txt
cp $ECW_SDK/ERDAS_ECW_JPEG2000_SDK.pdf $R/$P-ecw/$P-ecw-$V-$B.rtf
cp $MRSID_SDK/LICENSE.pdf $R/$P-mrsid/$P-mrsid-$V-$B.pdf


cp $FGDB_SDK/bin64/FileGDBAPI.dll $DESTDIR/bin
cp $ECW_SDK/bin/vc140/x64/NCSEcw.dll $DESTDIR/bin
cp $MRSID_SDK/Raster_DSDK/lib/lti_dsdk_cdll_9.5.dll $DESTDIR/bin
cp $MRSID_SDK/Raster_DSDK/lib/tbb.dll $DESTDIR/bin
cp $MRSID_SDK/Raster_DSDK/lib/lti_dsdk_9.5.dll $DESTDIR/bin
cp $MRSID_SDK/Lidar_DSDK/lib/lti_lidar_dsdk_1.1.dll $DESTDIR/bin

tar -C $PYDESTDIR --exclude="*.pyc" --exclude __pycache__ -cjvf $R/python3-$P/python3-$P-$V-$B.tar.bz2 \
	apps/$PYTHON

tar -C install --remove-files -cjvf $R/$P-filegdb/$P-filegdb-$V-$B.tar.bz2 \
	bin/gdalplugins/ogr_FileGDB.dll \
	bin/FileGDBAPI.dll

tar -C install --remove-files -cjvf $R/$P-sosi/$P-sosi-$V-$B.tar.bz2 \
	bin/gdalplugins/ogr_SOSI.dll

tar -C install --remove-files -cjvf $R/$P-oracle/$P-oracle-$V-$B.tar.bz2 \
	bin/gdalplugins/gdal_GEOR.dll \
	bin/gdalplugins/ogr_OCI.dll

tar -C install --remove-files -cjvf $R/$P-mss/$P-mss-$V-$B.tar.bz2 \
	bin/gdalplugins/ogr_MSSQLSpatial.dll

tar -C install --remove-files -cjvf $R/$P-ecw/$P-ecw-$V-$B.tar.bz2 \
	bin/gdalplugins/gdal_ECW_JP2ECW.dll \
	bin/NCSEcw.dll

tar -C install --remove-files -cjvf $R/$P-mrsid/$P-mrsid-$V-$B.tar.bz2 \
	bin/gdalplugins/gdal_MG4Lidar.dll \
	bin/gdalplugins/gdal_MrSID.dll \
	bin/lti_dsdk_cdll_9.5.dll \
	bin/lti_dsdk_9.5.dll \
	bin/lti_lidar_dsdk_1.1.dll \
	bin/tbb.dll

tar -C install --remove-files -cjvf $R/$P-hdf5/$P-hdf5-$V-$B.tar.bz2 \
	bin/gdalplugins/gdal_HDF5.dll

tar -C install --remove-files -cjvf $R/$P-$V-$B.tar.bz2 \
	bin \
	etc \
	include \
	lib \
	share

tar -C .. -cjvf $R/$P-$V-$B-src.tar.bz2 \
	osgeo4w/package.sh \
	osgeo4w/nmake.opt \
	osgeo4w/patch

rm -f no*

endlog
