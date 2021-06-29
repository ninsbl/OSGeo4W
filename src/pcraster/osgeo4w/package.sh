export P=pcraster
export V=4.3.1
export B=next
export MAINTAINER=JuergenFischer
export BUILDDEPENDS="gdal gdal-devel python3-core python3-devel python3-numpy python3-pybind11 xerces-c-devel qt5-devel qt5-oci qt5-oci-debug boost-devel"

source ../../../scripts/build-helpers

startlog

if [ -d ../$P-$V ]; then
	cd ../$P-$V
	git pull
	git submodule update --recursive
else
	git clone --recurse-submodules https://github.com/$P/$P.git --branch v$V --single-branch ../$P-$V
fi

cd ../osgeo4w

vs2019env
cmakeenv

mkdir -p install build

cd build

export INCLUDE="$(cygpath -aw ../osgeo4w/apps/Python39/Lib/site-packages/numpy/core/include);$INCLUDE"
export LIB="$(cygpath -aw ../osgeo4w/apps/Python39/Lib/site-packages/numpy/core/lib);$LIB"

export INCLUDE="$(cygpath -aw ../osgeo4w/apps/Python39/Lib/site-packages/pybind11/include);$INCLUDE"
export LIB="$(cygpath -aw ../osgeo4w/apps/Python39/Lib/site-packages/pybind11/lib);$LIB"

export LIB="$(cygpath -aw ../osgeo4w/apps/Python39/Libs);$LIB"

export INCLUDE="$(cygpath -aw ../osgeo4w/include);$INCLUDE"
export LIB="$(cygpath -aw ../osgeo4w/lib);$LIB"

export PATH="$(cygpath -a ../osgeo4w/bin):$(cygpath -a ../osgeo4w/apps/qt5/bin):$PATH"

cmake -G Ninja \
	-Wno-dev \
	-D CMAKE_PREFIX_PATH=$(cygpath -am ../osgeo4w/apps/qt5/lib/cmake) \
	-D CMAKE_TOOLCHAIN_FILE=$(cygpath -am ../msvs2019.cmake) \
	-D PCRASTER_LINK_STATIC_BOOST=ON \
	-D Boost_USE_STATIC_LIBS=ON \
	-D Boost_USE_STATIC_RUNTIME=OFF \
	-D Boost_LIB_PREFIX=lib \
	-D Boost_INCLUDE_DIR="$(cygpath -am ../osgeo4w/include/boost-1_74)" \
	-D Boost_LIBRARY_DIR="$(cygpath -am ../osgeo4w/lib)" \
	-D CMAKE_CXX_STANDARD=17 \
	-D CMAKE_BUILD_TYPE=Release \
	-D CMAKE_INSTALL_PREFIX=../install \
	-D XercesC_INCLUDE_DIR=$(cygpath -am ../osgeo4w/include) \
	-D XercesC_LIBRARY=$(cygpath -am ../osgeo4w/lib/xerces-c_3.lib) \
	-D Python3_EXECUTABLE=$(cygpath -am ../osgeo4w/bin/python.exe) \
	-D pybind11_DIR=$(cygpath -am ../osgeo4w/apps/Python39/Lib/site-packages/pybind11/share/cmake/pybind11) \
	-D PYBIND11_SYSTEM_INCLUDE=$(cygpath -aw ../osgeo4w/apps/Python39/Lib/site-packages/pybind11/include) \
	-D Python3_NumPy_INCLUDE_DIR=$(cygpath -am ../osgeo4w/apps/Python39/Lib/site-packages/numpy/core/include) \
	-D GDAL_DATA=$(cygpath -am ../osgeo4w/share/gdal) \
	-D Qt5_DIR=$(cygpath -am ../osgeo4w/apps/Qt5) \
	-D PCRASTER_BUILD_TEST=OFF \
        ../../$P-$V
ninja
ninja install

exit 1

cd ..

export R=$OSGEO4W_REP/x86_64/release/$P
mkdir -p $R $R/$P-devel

cat <<EOF >$R/setup.hint
sdesc: "The GEOS geometry library (Runtime)"
ldesc: "The GEOS geometry library (Runtime)"
category: Libs
requires: msvcrt2019
Maintainer: $MAINTAINER
EOF

cat <<EOF >$R/$P-devel/setup.hint
sdesc: "The GEOS geometry library (Development)"
ldesc: "The GEOS geometry library (Development)"
category: Libs
requires: $P
external-source: $P
Maintainer: $MAINTAINER
EOF

cp ../COPYING $R/$P-$V-$B.txt
cp ../COPYING $R/$P-devel/$P-devel-$V-$B.txt

tar -C .. -cjf $R/$P-$V-$B-src.tar.bz2 osgeo4w/package.sh

cd install

tar -cjf $R/$P-$V-$B.tar.bz2 \
	bin/*.dll

tar -cjf $R/$P-devel/$P-devel-$V-$B.tar.bz2 \
	lib \
	include

endlog
