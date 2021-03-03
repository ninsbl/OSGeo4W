export P=python3-wxpython
export V=4.1.1
export B=next
export MAINTAINER=JuergenFischer
export BUILDDEPENDS="base python3-core python3-setuptools python3-wheel python3-devel wxwidgets-devel"

source ../../../scripts/build-helpers

startlog

[ -f wxPython-$V.tar.gz ] || wget https://files.pythonhosted.org/packages/b0/4d/80d65c37ee60a479d338d27a2895fb15bbba27a3e6bb5b6d72bb28246e99/wxPython-$V.tar.gz
[ -f ../wxPython-$V/setup.py ] || {
	tar -C .. -xzf wxPython-$V.tar.gz
	rm -f patched
}
[ -f patched ] || {
	patch -d ../wxPython-$V -p1 --dry-run <wx.diff
	patch -d ../wxPython-$V -p1 <wx.diff
	touch patched
}

(
	fetchenv osgeo4w/bin/o4w_env.bat
	vs2019env

	type cl.exe

	cd ../wxPython-$V

	export INCLUDE="$(cygpath -aw ../osgeo4w/osgeo4w/lib/vc_x64_dll/mswu);$(cygpath -aw ../osgeo4w/osgeo4w/include);$INCLUDE"
	export LIB="$(cygpath -aw ../osgeo4w/osgeo4w/lib/vc_x64_dll);$LIB"
	python3 build.py build_py --release --x64 --use_syswx --extra_waf='--msvc_version="msvc 16.7"'

	python3 build.py bdist_wheel

	wheel=$(cygpath -aw dist/*.whl) addsrcfiles=osgeo4w/wx.diff adddepends=wxwidgets packagewheel
)

endlog
